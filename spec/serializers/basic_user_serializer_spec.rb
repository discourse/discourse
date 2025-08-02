# frozen_string_literal: true

RSpec.describe BasicUserSerializer do
  fab!(:user)
  let(:serializer) { BasicUserSerializer.new(user, scope: Guardian.new(user), root: false) }

  describe "#as_json" do
    let(:json) { serializer.as_json }

    it "returns the username" do
      expect(json[:username]).to eq(user.username)
      expect(json[:name]).to eq(user.name)
      expect(json[:avatar_template]).to eq(user.avatar_template)
    end

    describe "extended serializers" do
      let(:post_action) { Fabricate(:post_action, user: user) }
      let(:serializer) do
        PostActionUserSerializer.new(post_action, scope: Guardian.new(user), root: false)
      end
      it "returns the user correctly" do
        expect(serializer.user.username).to eq(user.username)
      end
    end

    it "doesn't return the name it when `enable_names` is false" do
      SiteSetting.enable_names = false
      expect(json[:name]).to eq(nil)
    end
  end

  describe "#status" do
    fab!(:user_status)

    before { user.user_status = user_status }

    describe "when status is enabled in settings" do
      before { SiteSetting.enable_user_status = true }

      it "doesn't add status by default" do
        serializer = BasicUserSerializer.new(user, root: false)
        json = serializer.as_json

        expect(json.keys).not_to include :status
      end

      context "when including user status" do
        let(:serializer) { BasicUserSerializer.new(user, root: false, include_status: true) }

        it "adds status if `include_status: true` has been passed" do
          json = serializer.as_json
          expect(json[:status]).to_not be_nil do |status|
            expect(status.description).to eq(user_status.description)
            expect(status.emoji).to eq(user_status.emoji)
          end
        end

        it "doesn't add expired user status" do
          user.user_status.ends_at = 1.minutes.ago
          json = serializer.as_json
          expect(json.keys).not_to include :status
        end

        it "doesn't return status if user doesn't have it set" do
          user.clear_status!
          user.reload

          json = serializer.as_json

          expect(json.keys).not_to include :status
        end
      end
    end

    describe "when status is disabled in settings" do
      before { SiteSetting.enable_user_status = false }

      it "doesn't add user status" do
        serializer = BasicUserSerializer.new(user, root: false, include_status: true)
        json = serializer.as_json

        expect(json.keys).not_to include :status
      end
    end
  end
end
