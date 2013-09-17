require 'eventmachine'
require 'yaml'
require 'erb'

module Statsd
  class MessageDispatchDaemon < EventMachine::Connection
    # Methods to be called when a statsd message comes in.
    @@receivers = []
    # Register a Module implementing an EventMachine::Connection -like
    # interface.
    #
    # receive_data methods on all registered modules will get called, but for
    # any other EM::Connection methods, the last registered module/method will
    # take precedence.
    def self.register_receiver(mod)
      begin
        method = mod.method('receive_data')
        @@receivers << method unless @@receivers.include?(method)
      rescue NameError
        raise ArgumentError.new("The passed module #{mod} doesn't implement a receive_data method.")
      end
      include mod
    end
    def self.receivers=(list)
      raise ArgumentError unless list.is_a?(Array)
      @@receivers = list
    end
    def self.receivers
      @@receivers
    end
    def receive_data(msg)
      @@receivers.each do |method|
        method.call(msg)
      end
    end
  end
  class Daemon
    def run(options)
      config = if options[:config] and options[:config].is_a?(Hash)
                 options[:config]
               elsif options[:config_file] and options[:config_file].is_a?(String)
                 YAML::load(ERB.new(IO.read(options[:config_file])).result)
               end

      EventMachine::run do
        ## statsd->graphite aggregation
        if config['graphite_host']
          MessageDispatchDaemon.register_receiver(Statsd::Aggregator)
          EventMachine::add_periodic_timer(config['flush_interval']) do
            counters,timers = Statsd::Aggregator.get_and_clear_stats!
            EventMachine.connect config['graphite_host'], config['graphite_port'], Statsd::Graphite do |conn|
              conn.counters = counters
              conn.timers = timers
              conn.flush_interval = config['flush_interval']
              conn.flush_stats
            end
          end
          ##

          ## statsd->statsd data relay
          if config['forwarding']
            Statsd::Forwarder.set_destinations(config['forwarding_destinations'])
            MessageDispatchDaemon.register_receiver(Statsd::Forwarder)

            Statsd::Forwarder.build_fresh_sockets
            EventMachine::add_periodic_timer(config['forwarding_socket_lifetime']) do
              Statsd::Forwarder.build_fresh_sockets
            end
          end
          ##

          puts "Going to listen on #{config['bind']}:#{config['port']}"
          EventMachine::open_datagram_socket(config['bind'], config['port'], MessageDispatchDaemon)
        end
      end
    end
  end
end
