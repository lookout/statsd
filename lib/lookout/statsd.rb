require 'socket'
require 'resolv'
require 'forwardable'

module Lookout
  class Statsd
    # initialize singleton instance to be an instance of
    # +Lookout::StatsdClient+, with the given options
    def self.create_instance(opts={})
      raise "Already initialized Statsd" if instance_set?
      @@instance ||= StatsdClient.new(opts)
    end

    # Explicitly set singleton instance. The instance must follow the
    # same API as +Lookout::StatsdClient+
    def self.set_instance(instance)
      raise "Already initialized Statsd" if instance_set?
      @@instance = instance
    end

    # Clear singleton instance, for use in testing ONLY
    def self.clear_instance
      @@instance = nil
    end

    # Check if the instance has been set
    def self.instance_set?
      defined?(@@instance) && !!@@instance
    end

    # Access singleton instance, which must have been initialized with
    # .create_instance or .set_instance
    def self.instance
      raise "Statsd has not been initialized" unless instance_set?
      @@instance
    end
  end

  class StatsdClient
    attr_accessor :host, :port, :prefix, :resolve_always, :batch_size

    def initialize(opts={})
      @host = opts[:host] || 'localhost'
      @port = opts[:port] || 8125
      @batch_size = opts[:batch_size] || 10
      @prefix = opts[:prefix]
      # set resolve_always to true unless localhost or specified
      @resolve_always = opts.fetch(:resolve_always, !is_localhost?)
      @socket = UDPSocket.new
      @send_data = send_method
    end

    def host_ip_addr
      @host_ip_addr ||= Resolv.getaddress(host)
    end

    def host=(h)
      @host_ip_addr = nil
      @host = h
    end

    # +stat+ to log timing for
    # +time+ is the time to log in ms
    def timing(stat, time = nil, sample_rate = 1)
      value = nil
      if block_given?
        start_time = Time.now.to_f
        value = yield
        time = ((Time.now.to_f - start_time) * 1000).floor
      end

      if @prefix
        stat = "#{@prefix}.#{stat}"
      end

      send_stats("#{stat}:#{time}|ms", sample_rate)
      value
    end

    # +stat+ to log timing for, from provided block
    def time(stat, sample_rate = 1)
      start_time = Time.now.to_f
      value = yield
    ensure
      timing(stat, ((Time.now.to_f - start_time) * 1000).floor, sample_rate)
      value
    end

    # +stats+ can be a string or an array of strings
    def increment(stats, sample_rate = 1)
      update_counter stats, 1, sample_rate
    end

    # +stats+ can be a string or an array of strings
    def decrement(stats, sample_rate = 1)
      update_counter stats, -1, sample_rate
    end

    # +stats+ can be a string or array of strings
    def update_counter(stats, delta = 1, sample_rate = 1)
      stats = Array(stats)
      p = @prefix ? "#{@prefix}." : '' # apply prefix to each
      send_stats(stats.map { |s| "#{p}#{s}:#{delta}|c" }, sample_rate)
    end

    alias_method :count, :update_counter

    # +stat_or_stats+ may either be a Hash OR a String. If it's a
    # String, then value must be specified. Other statsd client gems
    # have mostly standardized on using the String+value format, but
    # this gem traditionally supported just a Hash. This now supports
    # both for compatibility.
    def gauge(stat_or_stats, value=nil, opts=nil)
      # Can't use duck-typing here, since String responds to :map
      if stat_or_stats.is_a?(Hash)
        send_stats(stat_or_stats.map { |s,val|
                     if @prefix
                       s = "#{@prefix}.#{s}"
                     end
                     "#{s}:#{val}|g"
                   })
      else
        if @prefix
          stat_or_stats = "#{@prefix}.#{stat_or_stats}"
        end
        send_stats("#{stat_or_stats}:#{value}|g")
      end
    end

    def send_data(*args)
      @send_data.call(*args)
    end

    # Creates and yields a Batch that can be used to batch instrument reports into
    # larger packets. Batches are sent either when the packet is "full" (defined
    # by batch_size), or when the block completes, whichever is the sooner.
    #
    # Good artists copy https://github.com/reinh/statsd/blob/master/lib/statsd.rb#L410
    #
    # @yield [Batch] a statsd subclass that collects and batches instruments
    # @example Batch two instument operations:
    #   $statsd.batch do |batch|
    #     batch.increment 'sys.requests'
    #     batch.gauge {'user.count' => User.count}
    #   end
    def batch(&block)
      Batch.new(self).easy(&block)
    end

    private

    def send_stats(data, sample_rate = 1)
      data = Array(data)
      sampled_data = []

      # Apply sample rate if less than one
      if sample_rate < 1
        data.each do |d|
          if rand <= sample_rate
            sampled_data << "#{d}@#{sample_rate}"
          end
        end
        data = sampled_data
      end

      return if data.empty?

      raise "host and port must be set" unless host && port

      begin
        data.each do |d|
          @send_data[d]
        end
      rescue # silent but deadly
      end
      true
    end

    def socket_connect!
      @socket.connect(@host, @port)
    end

    # Curries the send based on if we need to lookup dns every time we send
    def send_method
      if resolve_always
        lambda {|data| @socket.send(data, 0, @host, @port)}
      else
        socket_connect!
        lambda {|data| @socket.send(data, 0)}
      end
    end

    def is_localhost?
      @host == 'localhost' || @host == '127.0.0.1'
    end
  end

  # Some more unabashed borrowing: https://github.com/reinh/statsd/blob/master/lib/statsd.rb#L410
  # The big difference between this implementation and reinh's is that we don't support namespaces,
  # and we have a bunch of hacks for introducing prefixes to the namespaces we're acting against.
  # = Batch: A batching statsd proxy
  #
  # @example Batch a set of instruments using Batch and manual flush:
  #   $statsd = Statsd.new 'localhost', 8125
  #   batch = Statsd::Batch.new($statsd)
  #   batch.increment 'garets'
  #   batch.timing 'glork', 320
  #   batch.gauge 'bork': 100
  #   batch.flush
  #
  # Batch is a subclass of Statsd, but with a constructor that proxies to a
  # normal Statsd instance. It has it's own batch_size parameters
  # (that inherit defaults from the supplied Statsd instance). It is recommended
  # that some care is taken if setting very large batch sizes. If the batch size
  # exceeds the allowed packet size for UDP on your network, communication
  # troubles may occur and data will be lost.
  class Batch < Lookout::StatsdClient

    attr_accessor :batch_size

    # @param [Statsd] requires a configured Statsd instance
    def initialize(statsd)
      @statsd = statsd
      @batch_size = statsd.batch_size
      @backlog = []
      @send_data = send_method
      @host = statsd.host
      @port = statsd.port
      @prefix = statsd.prefix
    end

    # @yields [Batch] yields itself
    #
    # A convenience method to ensure that data is not lost in the event of an
    # exception being thrown. Batches will be transmitted on the parent socket
    # as soon as the batch is full, and when the block finishes.
    def easy
      yield self
    ensure
      flush
    end

    def flush
      unless @backlog.empty?
        @statsd.send_data @backlog.join("\n")
        @backlog.clear
      end
    end

    def send_batch_data(message)
      @backlog << message
      if @backlog.size >= @batch_size
        flush
      end
    end

    def send_method
      lambda { |data|
        @backlog << data
        if @backlog.size >= @batch_size
          flush
        end
      }
    end
  end

  module Rails
    # to monitor all actions for this controller (and its descendents) with graphite,
    # use "around_filter Statsd::Rails::ActionTimerFilter"
    class ActionTimerFilter
      def self.filter(controller, &block)
        # Use params[:controller] insted of controller.controller_name to get full path.
        controller_name = controller.params[:controller].gsub("/", ".")
        key = "requests.#{controller_name}.#{controller.params[:action]}"
        Lookout::Statsd.instance.timing(key, &block)
      end
    end
  end
end
