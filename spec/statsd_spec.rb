require './lib/statsd.rb'

describe Statsd::Client do
  describe '#initialize' do
    it 'should work without arguments' do
      c = Statsd::Client.new
      c.should_not be nil
    end

    it 'should accept a :host keyword argument' do
      host = 'zombo.com'
      c = Statsd::Client.new(:host => host)
      c.host.should match(host)
    end

    it 'should accept a :port keyword argument' do
      port = 1337
      c = Statsd::Client.new(:port => port)
      c.port.should == port
    end
  end
end
