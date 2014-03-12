require 'spec_helper'
require_dependency 'pubsubhubbub_hub'

describe PubSubHubbubHub do
  describe '#ping' do
    it 'should send a POST request to the settinsg\'s hub with the right params' do
      urls = ['a', 'b', 'c']
      hub = 'h'
      mock_hub_site_setting = mock("pubsubhubbub_hub")
      SiteSetting.expects(:find_by_name).with('pubsubhubbub_hub').returns(mock_hub_site_setting)
      mock_hub_site_setting.expects(:try).with(:value).returns(hub)
      RestClient.expects(:post).with(hub, {:"hub.mode" => 'publish', :"hub.topic" => urls})
      PubSubHubbubHub.ping(urls)
    end
  end
end
