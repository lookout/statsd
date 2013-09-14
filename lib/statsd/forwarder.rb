require 'socket'

module Statsd
  module Forwarder
    @@sockets = {}
    @@destinations = []

    def self.sockets; @@sockets; end
    def self.sockets=(hash)
      raise ArgumentError unless hash.is_a?(Hash)
      @@sockets = hash
    end
    def self.destinations; @@destinations; end
    def self.destinations=(list)
      raise ArgumentError unless list.is_a?(Array)
      @@destinations = list
    end

    def self.receive_data(msg)
      # Broadcast the incoming message to all the forwarding destinations.
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
end
