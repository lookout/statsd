require 'eventmachine'
require 'statsd'
require 'statsd/server'
require 'statsd/graphite'

require 'yaml'
require 'erb'

ROOT = File.expand_path(File.dirname(__FILE__))
APP_CONFIG = YAML::load(ERB.new(IO.read(File.join(ROOT,'config.yml'))).result)

# Start the server
EventMachine::run do
  EventMachine::open_datagram_socket('127.0.0.1', 8125, Statsd::Server)
  EventMachine::add_periodic_timer(APP_CONFIG['flush_interval']) do
     counters,timers = Statsd::Server.get_and_clear_stats!

     # Graphite
     EventMachine.connect APP_CONFIG['graphite_host'], APP_CONFIG['graphite_port'], Statsd::Graphite do |conn|
       conn.counters = counters
       conn.timers = timers
       conn.flush_interval = 10
       conn.flush_stats
     end
  end


end
