# frozen_string_literal: true

describe UserStatusController do
  describe '#set' do
    it 'requires you to be logged in' do
      put "/user-status.json", params: { description: "off to dentist" }
      expect(response.status).to eq(403)
    end

    describe 'logged in' do
      fab!(:user) { Fabricate(:user) }

      before do
        sign_in(user)
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
    end
  end

  describe '#clear' do
    it 'requires you to be logged in' do
      delete "/user-status.json"
      expect(response.status).to eq(403)
    end

    describe 'logged in' do
      fab!(:user_status) { Fabricate(:user_status, description: "off to dentist") }
      fab!(:user) { Fabricate(:user, user_status: user_status) }

      before do
        sign_in(user)
      end

      it "clears user status" do
        delete "/user-status.json"

        user.reload
        expect(user.user_status).to be_nil
      end
    end
  end
end
