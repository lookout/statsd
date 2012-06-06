require 'spec_helper'


describe Statsd::Server do
  include Statsd::Server

  describe :receive_data do
    it 'should not vomit on bad data' do
      bad_data = "dev.rwygand.app.flexd.exception.no action responded to index. actions: authenticate, authentication_request, authorization, bubble_stacktrace?, decode_credentials, encode_credentials, not_found, and user_name_and_password:1|c"

      receive_data(bad_data)
    end

  end
end
