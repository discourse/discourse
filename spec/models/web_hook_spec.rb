require 'rails_helper'

describe WebHook do
  it { is_expected.to validate_presence_of :payload_url }
  it { is_expected.to validate_presence_of :content_type }
  it { is_expected.to validate_presence_of :last_delivery_status }
  it { is_expected.to validate_presence_of :web_hook_event_types }

  describe '#content_types' do
    before { @content_types = WebHook.content_types }

    it "'json' (application/json) should be at 1st position" do
      expect(@content_types['application/json']).to eq 1
    end

    it "'url_encoded' (application/x-www-form-urlencoded) should be at 2st position" do
      expect(@content_types['application/x-www-form-urlencoded']).to eq 2
    end
  end


  describe '#last_delivery_statuses' do
    before { @last_delivery_statuses = WebHook.last_delivery_statuses }

    it "inactive should be at 1st position" do
      expect(@last_delivery_statuses[:inactive]).to eq 1
    end

    it "failed should be at 2st position" do
      expect(@last_delivery_statuses[:failed]).to eq 2
    end

    it "successful should be at 3st position" do
      expect(@last_delivery_statuses[:successful]).to eq 3
    end
  end
end
