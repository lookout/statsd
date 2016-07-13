require 'spec_helper'

describe LookoutStatsd::Rails::ActionTimerFilter do

  describe ".filter" do
    before(:all) do
      Statsd.create_instance
    end

    it "should log the appropriate data with simple controller" do
      controller = mock_controller('control', 'act')
      Statsd.instance.should_receive(:timing).with("requests.control.act")
      LookoutStatsd::Rails::ActionTimerFilter.filter(controller) {}
    end

    it "should log the appropriate data with complex controller" do
      controller = mock_controller('api/v1/control', 'act')
      Statsd.instance.should_receive(:timing).with("requests.api.v1.control.act")
      LookoutStatsd::Rails::ActionTimerFilter.filter(controller) {}
    end
  end

  # Create a mock controller with the given name and action
  def mock_controller(name, action)
    controller = double("MyController")
    params = {
      :controller => name,
      :action => action,
    }
    controller.stub(:params).and_return(params)
    controller
  end
end
