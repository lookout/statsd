require 'json'
module Statsd
  module HTTPHealth
    class Server < EventMachine::Connection
      def receive_data(_)
        response_data = { "status" => "ok" }
        response_data.merge!(MessageHandler.rates)
        response_data = JSON.dump(response_data)

        send_data("HTTP/1.1 200 OK\r\n")
        send_data("Server: Ruby EventMachine/statsd\r\n")
        send_data("Content-Type: application/json\r\n")
        send_data("Content-Length: #{response_data.length}\r\n")
        send_data("Connection: close\r\n")
        send_data("\r\n")
        send_data(response_data)
        close_connection_after_writing
      end
    end
    module MessageHandler
      @@message_count = 0
      @@rates = {}
      @@previous_message_counts = {}
      def self.begin
        [5, 10, 60].each do |seconds|
          EventMachine.add_periodic_timer(seconds) do
            key = "#{seconds}_seconds"
            @@previous_message_counts[key] ||= 0
            @@rates[key] = ((@@message_count - @@previous_message_counts[key]) / seconds.to_f)
            @@previous_message_counts[key] = @@message_count
          end
        end

      end
      def self.rates
        @@rates
      end
      def self.increment
        @@message_count += 1
      end
      def self.receive_data(msg)
        self.increment
      end
    end
  end
end
