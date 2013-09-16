module Statsd
  module Aggregator
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

  end
end
