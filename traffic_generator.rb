#!/usr/bin/env ruby
require 'socket'
s = UDPSocket.new
s.connect 'localhost', 8125

random_stats = []
100.times { random_stats << ((0...8).map { (65 + rand(26)).chr }.join) }
loop do
  random_stats.each do |stat|
    s.send "stat:#{rand(10)}|c", 0
  end
end
