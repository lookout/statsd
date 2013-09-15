# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name        = "lookout-statsd"
  s.version     = "0.8.0"
  s.platform    = Gem::Platform::RUBY

  s.authors     = ['R. Tyler Croy', 'Andrew Coldham', 'Ben VandenBos']
  s.email       = ['rtyler.croy@mylookout.com']
  s.homepage    = "https://github.com/lookout/statsd"

  s.summary     = "Ruby version of statsd."
  s.description = "A network daemon for aggregating statistics (counters and timers), rolling them up, then sending them to graphite."

  s.required_rubygems_version = ">= 1.3.6"

  s.add_dependency "eventmachine",  ">= 0.12.10"
  s.add_dependency "erubis",        ">= 2.6.6"

  s.files        = `git ls-files`.split("\n")
  s.executables  = `git ls-files`.split("\n").map{|f| f =~ /^bin\/(.*)/ ? $1 : nil}.compact
  s.require_path = 'lib'
end

