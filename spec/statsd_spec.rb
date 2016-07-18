require 'spec_helper'

describe Lookout::Statsd do
  before(:each) do
    described_class.clear_instance
  end

  after(:each) do
    described_class.clear_instance
  end

  describe '.create_instance' do
    it 'should create an instance' do
      described_class.create_instance
      described_class.instance.should_not be nil
    end

    context 'if an instance has been created' do
      before :each do
        described_class.create_instance
      end
      it 'should raise if called twice' do
        expect { described_class.create_instance }.to raise_error
      end
    end
  end

  describe '.set_instance' do
    let(:instance) { double('Statsd') }

    it 'should set instance' do
      described_class.set_instance(instance)
      expect(described_class.instance).to eq instance
    end

    context 'if an instance has been created' do
      before :each do
        described_class.set_instance(instance)
      end
      it 'should raise if called twice' do
        expect { described_class.set_instance(instance) }.to raise_error
      end
    end
  end

  describe '#instance' do
    it 'should raise if not created' do
      expect { described_class.instance }.to raise_error
    end
  end
end

describe Lookout::StatsdClient do
  describe '#initialize' do
    it 'should work without arguments' do
      c = Lookout::StatsdClient.new
      c.should_not be nil
    end

    it 'should accept a :host keyword argument' do
      host = 'zombo.com'
      c = Lookout::StatsdClient.new(:host => host)
      c.host.should match(host)
    end

    it 'should accept a :port keyword argument' do
      port = 1337
      c = Lookout::StatsdClient.new(:port => port)
      c.port.should == port
    end

    it 'should accept a :prefix keyword argument' do
      prefix = 'dev'
      c = Lookout::StatsdClient.new(:prefix => prefix)
      c.prefix.should match(prefix)
    end

    it 'should accept a :resolve_always keyword argument' do
      lookup = false
      c = Lookout::StatsdClient.new(:resolve_always => lookup)
      c.resolve_always.should be(lookup)
    end

    context 'when :resolve_always is not specified' do

      context 'when host is localhost or 127.0.0.1' do
        it ':resolve_always should default to false' do
          c = Lookout::StatsdClient.new(:host => 'localhost')
          c.resolve_always.should be(false)
        end
      end

      context 'when host is not local' do
        it ':resolve_always should default to true' do
          c = Lookout::StatsdClient.new(:host => 'statsd.example.example')
          c.resolve_always.should be(true)
        end
      end

    end

  end

  describe '#send_stats' do

    it 'should use cached resolve address when :resolve_always is false' do
      c = Lookout::StatsdClient.new(:resolve_always => false)
      sock = c.instance_variable_get(:@socket)
      expect(sock).to receive(:send).with(anything, 0)
      c.increment('foo')
    end

    it 'should always resolve address when :resolve_always is true' do
      c = Lookout::StatsdClient.new(:resolve_always => true)
      sock = c.instance_variable_get(:@socket)
      expect(sock).to receive(:send).with(anything, 0, c.host, c.port)
      c.increment('foo')
    end
  end

  describe '#timing' do
    let(:c) { Lookout::StatsdClient.new }

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

  describe '#time' do
    let(:c) { Lookout::StatsdClient.new }
    let(:value) { 1337 }
    let(:sample_rate) { 3 }

    before :each do
      # Pretend our block took one second
      Time.stub_chain(:now, :to_f).and_return(1, 2)
    end

    it 'should wrap a block correctly' do
      expect(c).to receive(:timing).with('foo', 1000, 1)
      c.time('foo') { true }
    end

    it 'should pass along sample rate' do
      expect(c).to receive(:timing).with('foo', 1000, sample_rate)
      c.time('foo', sample_rate) { true }
    end

    it 'should return the return value from the block' do
      value = c.time('foo') { value }
      expect(value).to eq value
    end
  end

  describe '#increment' do
    let(:c) { Lookout::StatsdClient.new }

    it 'should update the counter by 1' do
      c.should_receive(:update_counter).with('foo', 1, anything())
      c.increment('foo')
    end
  end

  describe '#decrement' do
    let(:c) { Lookout::StatsdClient.new }

    it 'should update the counter by -1' do
      c.should_receive(:update_counter).with('foo', -1, anything())
      c.decrement('foo')
    end
  end

  describe '#update_counter' do
    let(:c) { Lookout::StatsdClient.new }

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

  describe '#count' do
    let(:c) { Lookout::StatsdClient.new }

    it 'should behave like update_counter' do
      c.should_receive(:send_stats).with(['foo:123|c'], 1)
      c.update_counter('foo', 123, 1)
    end
  end

  describe '#gauge' do
    let(:c) { Lookout::StatsdClient.new }

    context "called with a Hash" do
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

    context "called with String+Value" do
      context "without specifying options" do
        it 'should encode the values correctly' do
          c.should_receive(:send_stats).with('foo:1|g')
          c.gauge('foo', 1)
        end

        it 'should prepend the prefix if it has one' do
          c.prefix = 'dev'
          c.should_receive(:send_stats).with('dev.foo:1|g')
          c.gauge('foo', 1)
        end
      end

      context "specifying options" do
        let(:opts) { {:ignored => true} }

        it 'should encode the values correctly' do
          c.should_receive(:send_stats).with('foo:1|g')
          c.gauge('foo', 1, opts)
        end

        it 'should prepend the prefix if it has one' do
          c.prefix = 'dev'
          c.should_receive(:send_stats).with('dev.foo:1|g')
          c.gauge('foo', 1, opts)
        end
      end
    end
  end

  describe '#batch' do
    let(:c) { Lookout::StatsdClient.new }
    subject { c.batch { |b| b.increment('foo'); b.increment('bar'); } }

    it 'should take a block and put increments into a buffer' do
      Lookout::Batch.any_instance do |b|
        b.backlog.should_receive(:<<).exactly.twice
      end
      Lookout::Batch.any_instance.should_receive(:flush).and_call_original
      c.should_receive(:send_data).once
      subject
    end
  end
end

describe Lookout::Batch do
  let(:c) { Lookout::StatsdClient.new :host => 'foo.com', :prefix => 'my.app', :port => 1234, :batch_size => 20 }

  it 'should delegate fields correctly' do
    c.batch do |b|
      expect(b.host).to eql 'foo.com'
      expect(b.prefix).to eql 'my.app'
      expect(b.port).to eql 1234
      expect(b.batch_size).to eql 20
    end
  end

  describe '#gauge' do
    it 'should apply the prefix correctly' do
      c.batch do |b|
        b.should_receive(:send_stats).with(["my.app.an_incrementer:2|g"])
        b.gauge({'an_incrementer' => 2})
      end
    end
  end

  describe '#timing' do

    before :each do
      c.prefix = nil
    end

    it 'should pass the sample rate along' do
      sample = 10
      c.batch do |b|
        b.should_receive(:send_stats).with(anything(), sample)
        b.timing('foo', 1, sample)
      end
    end

    it 'should use the right stat name' do
      c.batch do |b|
        b.should_receive(:send_stats).with('foo:1|ms', anything())
        b.timing('foo', 1)
      end
    end

    it 'should prefix its stats if it has a prefix' do
      c.prefix = 'dev'
      c.batch do |b|
        b.should_receive(:send_stats).with('dev.foo:1|ms', anything())
        b.timing('foo', 1)
      end
    end

    it 'should wrap a block correctly' do
      # Pretend our block took one second
      c.batch do |b|
        b.should_receive(:send_stats).with('foo:1000|ms', anything())
        Time.stub_chain(:now, :to_f).and_return(1, 2)

        b.timing('foo') do
          true.should be true
        end
      end
    end

    it 'should return the return value from the block' do
      # Pretend our block took one second
      c.batch do |b|
        b.should_receive(:send_stats).with('foo:1000|ms', anything())
        Time.stub_chain(:now, :to_f).and_return(1, 2)

        value = b.timing('foo') { 1337 }
        value.should == 1337
      end
    end
  end

  describe '#increment' do
    it 'should update the counter by 1' do
      c.should_receive(:update_counter).with('foo', 1, anything())
      c.increment('foo')
    end
  end

  describe '#decrement' do
    it 'should update the counter by -1' do
      c.batch do |b|
        b.should_receive(:update_counter).with('foo', -1, anything())
        b.decrement('foo')
      end
    end
  end

  describe '#update_counter' do
    it 'should prepend the prefix if it has one' do
      c.prefix = 'dev'
      c.batch do |b|
        b.should_receive(:send_stats).with(['dev.foo:123|c'], anything())
        b.update_counter('foo', 123)
      end
    end

    it 'should prepend multiple prefixes if it has one' do
      c.prefix = 'dev'
      c.batch do |b|
        b.should_receive(:send_stats).with(['dev.foo:123|c', 'dev.bar:123|c'], anything())
        b.update_counter(['foo', 'bar'], 123)
      end
    end
  end
end
