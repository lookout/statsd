# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name        = "lookout-statsd"
  s.version     = "1.1.0"
  s.platform    = Gem::Platform::RUBY

  s.authors     = ['R. Tyler Croy', 'Andrew Coldham', 'Ben VandenBos']
  s.email       = ['rtyler.croy@mylookout.com']
  s.homepage    = "https://github.com/lookout/statsd"

  s.summary     = "Ruby statsd client."
  s.description = "A simple ruby statsd client."

  s.required_rubygems_version = ">= 1.3.6"

  s.files        = `git ls-files`.split("\n")
  s.executables  = `git ls-files`.split("\n").map{|f| f =~ /^bin\/(.*)/ ? $1 : nil}.compact
  s.require_path = 'lib'
end
