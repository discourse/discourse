require 'spec_helper'
require_dependency 'pubsubhubbub_hub'

describe PubSubHubbubHub do
  before do
    ENV['FORCE_PUSH'] = 'true'
  end

  after do
    ENV.delete 'FORCE_PUSH'
  end

  describe '#ping' do
    it 'should send a POST request to the settings\'s hub with the right params' do
      urls = ['a', 'b', 'c']
      hub = 'h'
      mock_hub_site_setting = mock("pubsubhubbub_hub")
      SiteSetting.expects(:pubsubhubbub_hub).returns(hub)
      RestClient.expects(:post).with(hub, {:"hub.mode" => 'publish', :"hub.topic" => urls})
      PubSubHubbubHub.ping(urls)
    end
  end
end
