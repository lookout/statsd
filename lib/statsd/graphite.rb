require 'benchmark'
require 'eventmachine'


module Statsd
  class Graphite < EM::Connection
    attr_accessor :counters, :timers, :flush_interval

    def flush_stats
      puts "#{Time.now} Flushing #{counters.count} counters and #{timers.count} timers to Graphite."

      stat_string = ''

      ts = Time.now.to_i
      num_stats = 0

      # store counters
      counters.each_pair do |key,value|
        message = "#{key} #{value} #{ts}\n"
        stat_string += message
        counters[key] = 0

        num_stats += 1
      end

      # store timers
      timers.each_pair do |key, values|
        if (values.length > 0)
          pct_threshold = 90
          values.sort!
          count = values.count
          min = values.first
          max = values.last

          mean = min
          max_at_threshold = max

          if (count > 1)
            # average all the timing data
            sum = values.inject( 0 ) { |s,x| s+x }
            mean = sum / values.count

            # strip off the top 100-threshold
            threshold_index = (((100 - pct_threshold) / 100.0) * count).round
            values = values[0..-threshold_index]
            max_at_threshold = values.last
          end

          message = ""
          message += "#{key}.mean #{mean} #{ts}\n"
          message += "#{key}.upper #{max} #{ts}\n"
          message += "#{key}.upper_#{pct_threshold} #{max_at_threshold} #{ts}\n"
          message += "#{key}.lower #{min} #{ts}\n"
          message += "#{key}.count #{count} #{ts}\n"
          stat_string += message

          timers[key] = []

          num_stats += 1
        end
      end

      stat_string += "statsd.numStats #{num_stats} #{ts}\n"

      # send to graphite
      send_data stat_string
      close_connection_after_writing
    end
  end
end
