source :gemcutter

gem "rake"

group :test do
  if RUBY_VERSION > "1.9"
    gem "ruby-debug19", :require => 'ruby-debug'
  else
    gem "ruby-debug"
  end

  gem "rspec"
  gem "cucumber"
end
