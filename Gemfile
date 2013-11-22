source "https://rubygems.org"

gem "rake"

group :test do
  if RUBY_VERSION > "1.9"
    gem "ruby-debug19", :require => 'ruby-debug'
  else
    gem "ruby-debug"
  end

  gem "rspec"
  gem "cucumber"

  gem 'guard', "< 2.0"
  gem 'guard-rspec', "< 4.0"
  gem 'pry'
end


gemspec
