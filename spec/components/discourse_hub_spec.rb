require 'rails_helper'
require_dependency 'discourse_hub'

describe DiscourseHub do
  describe '#discourse_version_check' do
    it 'should return just return the json that the hub returns' do
      hub_response = {'success' => 'OK', 'latest_version' => '0.8.1', 'critical_updates' => false}
      RestClient.stubs(:get).returns( hub_response.to_json )
      expect(DiscourseHub.discourse_version_check).to eq(hub_response)
    end
  end
end
