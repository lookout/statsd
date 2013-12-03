source "https://rubygems.org"

gem "rake"
gem "json"

group :test do
  if RUBY_VERSION > "1.9"
    gem "ruby-debug19", :require => 'ruby-debug'
  else
    gem "ruby-debug"
  end

  gem "rspec"
  gem "cucumber"

  gem 'guard'
  gem 'guard-rspec'
  gem 'pry'
end


gemspec
