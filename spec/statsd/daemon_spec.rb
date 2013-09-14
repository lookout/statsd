require 'spec_helper'

describe Statsd::Daemon do
  describe :new do
    before(:each) do
      EventMachine.should_receive(:run) { |&block| block.call }
      EventMachine.should_receive(:open_datagram_socket).and_return true
      EventMachine.should_receive(:add_periodic_timer).at_least(:once) { |delay, &block| block.call }
      EventMachine.should_receive(:connect).and_return true
      Statsd::MessageDispatchDaemon.receivers = []
    end

    it 'Should extend MessageDispatchDaemon with an Aggregator if "carbon_cache" is configured' do
      config = {
        "bind"=>"127.0.0.1",
        "port"=>8125,
        "flush_interval"=>5,
        "graphite_host"=>"localhost",
        "graphite_port"=>2003,
        "forwarding"=>false,
      }

      Statsd::Daemon.new.run(:config => config)
      Statsd::MessageDispatchDaemon.receivers.should eq([Statsd::Aggregator.method(:receive_data)])
    end

    it 'Should extend MessageDispatchDaemon with an Aggregator and Forwarder if "carbon_cache" is configured and forwarding is enabled' do
      config = {
        "bind"=>"127.0.0.1",
        "port"=>8125,
        "flush_interval"=>5,
        "graphite_host"=>"localhost",
        "graphite_port"=>2003,
        "forwarding"=>true,
        "forwarding_destinations"=>
          [
            {"port"=>9000, "hostname"=>"localhost"},
            {"port"=>9001, "hostname"=>"127.0.0.1"}
          ]
      }

      Statsd::Daemon.new.run(:config => config)
      Statsd::MessageDispatchDaemon.receivers.should eq([Statsd::Aggregator.method(:receive_data), Statsd::Forwarder.method(:receive_data)])
    end
  end
end

