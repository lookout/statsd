require 'spec_helper'

describe Statsd do
  describe '#create_instance' do
    before(:each) do
      # Make sure prior test hasn't already invoked create_instance
      if Statsd.class_variable_defined?(:@@instance)
        Statsd.send(:remove_class_variable, :@@instance)
      end
    end

    after(:each) do
      Statsd.send(:remove_class_variable, :@@instance)
    end

    it 'should create an instance' do
      Statsd.create_instance
      Statsd.instance.should_not be nil
    end

    it 'should raise if called twice' do
      Statsd.create_instance
      expect { Statsd.create_instance }.to raise_error
    end
  end

  describe '#instance' do
    it 'should raise if not created' do
      expect { Statsd.instance }.to raise_error
    end
  end
end

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

    it 'should accept a :prefix keyword argument' do
      prefix = 'dev'
      c = Statsd::Client.new(:prefix => prefix)
      c.prefix.should match(prefix)
    end

    it 'should accept a :resolve_always keyword argument' do
      lookup = false
      c = Statsd::Client.new(:resolve_always => lookup)
      c.resolve_always.should be(lookup)
    end

    context 'when :resolve_always is not specified' do

      context 'when host is localhost or 127.0.0.1' do
        it ':resolve_always should default to false' do
          c = Statsd::Client.new(:host => 'localhost')
          c.resolve_always.should be(false)
        end
      end

      context 'when host is not local' do
        it ':resolve_always should default to true' do
          c = Statsd::Client.new(:host => 'statsd.example.example')
          c.resolve_always.should be(true)
        end
      end

    end

  end

  describe '#send_stats' do

    it 'should use cached resolve address when :resolve_always is false' do
      c = Statsd::Client.new(:resolve_always => false)
      sock = c.instance_variable_get(:@socket)
      expect(sock).to receive(:send).with(anything, 0)
      c.increment('foo')
    end

    it 'should always resolve address when :resolve_always is true' do
      c = Statsd::Client.new(:resolve_always => true)
      sock = c.instance_variable_get(:@socket)
      expect(sock).to receive(:send).with(anything, 0, c.host, c.port)
      c.increment('foo')
    end
  end

  describe '#timing' do
    let(:c) { Statsd::Client.new }

    it 'should pass the sample rate along' do
      sample = 10
      c.should_receive(:send_stats).with(anything(), sample)
      c.timing('foo', 1, sample)
    end

    it 'should use the right stat name' do
      c.should_receive(:send_stats).with('foo:1|ms', anything())
      c.timing('foo', 1)
    end

    it 'should prefix its stats if it has a prefix' do
      c.should_receive(:send_stats).with('dev.foo:1|ms', anything())
      c.prefix = 'dev'
      c.timing('foo', 1)
    end

    it 'should wrap a block correctly' do
      # Pretend our block took one second
      c.should_receive(:send_stats).with('foo:1000|ms', anything())
      Time.stub_chain(:now, :to_f).and_return(1, 2)

      c.timing('foo') do
        true.should be true
      end
    end

    it 'should return the return value from the block' do
      # Pretend our block took one second
      c.should_receive(:send_stats).with('foo:1000|ms', anything())
      Time.stub_chain(:now, :to_f).and_return(1, 2)

      value = c.timing('foo') { 1337 }
      value.should == 1337
    end
  end

  describe '#increment' do
    let(:c) { Statsd::Client.new }

    it 'should update the counter by 1' do
      c.should_receive(:update_counter).with('foo', 1, anything())
      c.increment('foo')
    end
  end

  describe '#decrement' do
    let(:c) { Statsd::Client.new }

    it 'should update the counter by -1' do
      c.should_receive(:update_counter).with('foo', -1, anything())
      c.decrement('foo')
    end
  end

  describe '#update_counter' do
    let(:c) { Statsd::Client.new }

    it 'should prepend the prefix if it has one' do
      c.prefix = 'dev'
      c.should_receive(:send_stats).with(['dev.foo:123|c'], anything())
      c.update_counter('foo', 123)
    end

    it 'should prepend multiple prefixes if it has one' do
      c.prefix = 'dev'
      c.should_receive(:send_stats).with(['dev.foo:123|c', 'dev.bar:123|c'], anything())
      c.update_counter(['foo', 'bar'], 123)
    end
  end

  describe '#gauge' do
    let(:c) { Statsd::Client.new }

    it 'should encode the values correctly' do
      c.should_receive(:send_stats).with do |array|
        array.should include('foo:1|g')
        array.should include('bar:2|g')
      end
      c.gauge('foo' => 1, 'bar' => 2)
    end

    it 'should prepend the prefix if it has one' do
      c.prefix = 'dev'
      c.should_receive(:send_stats).with(['dev.foo:1|g'])
      c.gauge('foo' => 1)
    end
  end

  describe '#batch' do
    let(:c) { Statsd::Client.new }
    subject { c.batch { |b| b.increment('foo'); b.increment('bar'); } }

    it 'should take a block and put increments into a buffer' do
      Statsd::Batch.any_instance do |b|
        b.backlog.should_receive(:<<).exactly.twice
      end
      Statsd::Batch.any_instance.should_receive(:flush).and_call_original
      c.should_receive(:send_data).once
      subject
    end
  end
end