require 'eventmachine'
require 'yaml'
require 'erb'

require 'statsd/graphite'

module Statsd
  module Server
    Version = '0.5.5'

    FLUSH_INTERVAL = 10
    COUNTERS = {}
    TIMERS = {}
    GAUGES = {}

    def post_init
      puts "statsd server started!"
    end

    def self.get_and_clear_stats!
      counters = COUNTERS.dup
      timers = TIMERS.dup
      gauges = GAUGES.dup
      COUNTERS.clear
      TIMERS.clear
      GAUGES.clear
      [counters,timers,gauges]
    end

    def self.receive_data(msg)
      msg.split("\n").each do |row|
        bits = row.split(':')
        key = bits.shift.gsub(/\s+/, '_').gsub(/\//, '-').gsub(/[^a-zA-Z_\-0-9\.]/, '')
        bits.each do |record|
          sample_rate = 1
          fields = record.split("|")
          if fields.nil? || fields.count < 2
            next
          end
          if (fields[1].strip == "ms")
            TIMERS[key] ||= []
            TIMERS[key].push(fields[0].to_i)
          elsif (fields[1].strip == "c")
            if (fields[2] && fields[2].match(/^@([\d\.]+)/))
              sample_rate = fields[2].match(/^@([\d\.]+)/)[1]
            end
            COUNTERS[key] ||= 0
            COUNTERS[key] += (fields[0].to_i || 1) * (1.0 / sample_rate.to_f)
          elsif (fields[1].strip == "g")
            GAUGES[key] ||= (fields[0].to_i || 0)
          else
            puts "Invalid statistic #{fields.inspect} received; ignoring"
          end
        end
      end
    end

    module Forwarder
      @@sockets = {}
      @@destinations = []
      def receive_data(msg)
        # Send data to the normal, local Statsd instance.
        Statsd::Server.receive_data(msg)
        # And then also multicast the message to the forwarding destinations.
        @@sockets.each do |destination, socket|
          begin
            socket.send(msg, 0)
          rescue SocketError, Errno::ECONNREFUSED => e
            puts "ERROR: Couldn't send message to #{destination}. Stopping this output.(#{e.inspect})"
            @@sockets.delete(destination)
          end
        end
      end
      def self.build_fresh_sockets
        # Reset destinations to those destinations for which we could
        # actually get a socket going.
        @@sockets.clear
        @@destinations = @@destinations.select do |destination|
          begin
            s = UDPSocket.new(Socket::AF_INET)
            s.connect destination['hostname'], destination['port']
            @@sockets[destination] = s
            true
          rescue SocketError
            puts "ERROR: Couldn't create a socket to #{destination}/#{port}. Pruning destination from Forwarder. (#{e.inspect})"
            false
          end
        end
      end
      def self.set_destinations(destinations)
        raise ArgumentError unless destinations.is_a?(Array)
        raise ArgumentError unless destinations.map { |d| d.keys }.flatten.uniq.sort == ['hostname', 'port']
        @@destinations = destinations
      end
    end
    class Daemon
      def run(options)
        config = YAML::load(ERB.new(IO.read(options[:config])).result)

        EventMachine::run do
          if config['forwarding']
            Statsd::Server::Forwarder.set_destinations(config['forwarding_destinations'])
            EventMachine::add_periodic_timer(config['flush_interval']) { Statsd::Server::Forwarder.build_fresh_sockets }
            EventMachine::open_datagram_socket(config['bind'], config['port'], Statsd::Server::Forwarder)
          else
            EventMachine::open_datagram_socket(config['bind'], config['port'], Statsd::Server)
          end
          puts "Listening on #{config['bind']}:#{config['port']}"

          # Periodically Flush
          EventMachine::add_periodic_timer(config['flush_interval']) do
            counters,timers = Statsd::Server.get_and_clear_stats!

            EventMachine.connect config['graphite_host'], config['graphite_port'], Statsd::Graphite do |conn|
              conn.counters = counters
              conn.timers = timers
              conn.flush_interval = config['flush_interval']
              conn.flush_stats
            end
          end
        end
      end
    end
  end
end
