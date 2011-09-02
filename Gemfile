source :gemcutter
source 'http://maestro.mylookout.com:8001'

gem "rake"

group :test do
  if RUBY_VERSION > "1.9"
    gem "ruby-debug19", :require => 'ruby-debug'
  else
    gem "ruby-debug"
  end
end
