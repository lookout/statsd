require 'spec_helper'
require 'timeout'

describe Statsd::Forwarder do
  let(:destinations) do
    [ {'hostname'=>'localhost', 'port'=>9000},
      {'hostname'=>'127.0.0.1', 'port'=>9001} ]
  end
  before(:each) do
    Statsd::Forwarder.sockets = {}
    expect { Statsd::Forwarder.set_destinations(destinations) }.not_to raise_error
  end
  it 'Should accept a list of destinations to forward to.' do
    Statsd::Forwarder.destinations.should eq(destinations)
  end
  it 'Should create sockets to the destinations with #build_fresh_sockets' do
    Statsd::Forwarder.sockets.should eq({})
    Statsd::Forwarder.build_fresh_sockets
    Statsd::Forwarder.sockets.should be_a_kind_of(Hash)
    Statsd::Forwarder.sockets.keys.length.should eq(destinations.length)
    Statsd::Forwarder.sockets.values.each { |socket| socket.should be_a_kind_of(UDPSocket) }
  end
  describe 'Replicating incoming messages' do
    let(:socket_one) do
      u = UDPSocket.new
      u.bind('127.0.0.1', 0)
      #let(:socket_one_port) { u.local_address.ip_port }
      u
    end
    let(:socket_two) do
      u = UDPSocket.new
      u.bind('127.0.0.1', 0)
      u
    end
    let(:test_stat) { "app.thing.speed:10|ms\n" }
    it 'Registers two local receivers, Gets an incoming message, both receivers get it' do
      Statsd::Forwarder.set_destinations([{'hostname' => '127.0.0.1', 'port' => socket_one.addr[1] },
                                          {'hostname' => '127.0.0.1', 'port' => socket_two.addr[1] }])
      Statsd::Forwarder.build_fresh_sockets
      Statsd::Forwarder.receive_data(test_stat)

      Timeout.timeout(3) do
        msg, _, _ = socket_one.recv(4_096)
        msg.should eq(test_stat)

        msg, _, _ = socket_two.recv(4_096)
        msg.should eq(test_stat)
      end
    end
  end
end
