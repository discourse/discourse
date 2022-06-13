# frozen_string_literal: true

describe UserStatusController do
  describe '#set' do
    it 'requires user to be logged in' do
      put "/user-status.json", params: { description: "off to dentist" }
      expect(response.status).to eq(403)
    end

    it "returns 404 if the feature is disabled" do
      user = Fabricate(:user)
      sign_in(user)
      SiteSetting.enable_user_status = false

      put "/user-status.json", params: { description: "off" }

      expect(response.status).to eq(404)
    end

    describe 'feature is enabled and user is logged in' do
      fab!(:user) { Fabricate(:user) }

      before do
        sign_in(user)
        SiteSetting.enable_user_status = true
      end

      it "sets user status" do
        status = "off to dentist"
        put "/user-status.json", params: { description: status }
        expect(user.user_status.description).to eq(status)
      end

      it 'the description parameter is mandatory' do
        put "/user-status.json", params: {}
        expect(response.status).to eq(400)
      end

      it "following calls update status" do
        status = "off to dentist"
        put "/user-status.json", params: { description: status }
        user.reload
        expect(user.user_status.description).to eq(status)

        new_status = "working"
        put "/user-status.json", params: { description: new_status }
        user.reload
        expect(user.user_status.description).to eq(new_status)
      end

      it "publishes to message bus" do
        status = "off to dentist"

        messages = MessageBus.track_publish(User.publish_updates_channel(user.id)) do
          put "/user-status.json", params: { description: status }
          expect(response.status).to eq(200)
        end

        expect(messages.size).to eq(1)
        expect(messages[0].data[:type]).to eq(User::PUBLISH_USER_STATUS_TYPE)
        expect(messages[0].data[:payload][:description]).to eq(status)
        expect(messages[0].user_ids).to eq([user.id])
      end
    end
  end

  describe '#clear' do
    it 'requires you to be logged in' do
      delete "/user-status.json"
      expect(response.status).to eq(403)
    end

    it "returns 404 if the feature is disabled" do
      user = Fabricate(:user)
      sign_in(user)
      SiteSetting.enable_user_status = false

      delete "/user-status.json"

      expect(response.status).to eq(404)
    end

    describe 'feature is enabled and user is logged in' do
      fab!(:user_status) { Fabricate(:user_status, description: "off to dentist") }
      fab!(:user) { Fabricate(:user, user_status: user_status) }

      before do
        sign_in(user)
        SiteSetting.enable_user_status = true
      end

      it "clears user status" do
        delete "/user-status.json"

        user.reload
        expect(user.user_status).to be_nil
      end

      it "publishes to message bus" do
        messages = MessageBus.track_publish(User.publish_updates_channel(user.id)) do
          delete "/user-status.json"

          expect(response.status).to eq(200)
        end

        expect(messages.size).to eq(1)
        expect(messages[0].data[:type]).to eq(User::PUBLISH_USER_STATUS_TYPE)
        expect(messages[0].data[:payload]).to eq(nil)
        expect(messages[0].user_ids).to eq([user.id])
      end
    end
  end
end
