require 'spec_helper'
require 'push_notifications'

RSpec.describe PushNotifications do
  let(:registration_id) { 'abcdefghi' }
  let(:endpoint) { "#{PushNotifications::GCM_ENDPOINT}/#{registration_id}" }

  describe ".registration_id" do
    it "extracts the registration id from the endpoint" do
      expect(described_class.send('extract_registration_id', endpoint)).to eq(registration_id)
    end
  end

  describe ".push" do
    let(:user) { Fabricate(:user) }

    context "when user is subscribed" do
      before do
        PushNotifications.subscribe(user, endpoint)
      end

      after do
        PushNotifications.unsubscribe(user, endpoint)
      end

      it "does not send a push message if google cloud message has not been set up" do
        SiteSetting.gcm_api_key = nil
        Excon.expects(:post).never
        PushNotifications.push(user)
      end
    end

    context "when user is not subscribed" do
      it "does not send a push message" do
        SiteSetting.gcm_api_key = 'abcde'
        Excon.expects(:post).never
        PushNotifications.push(user)
      end
    end
  end
end
