# frozen_string_literal: true

RSpec.describe UserCardSerializer do
  context "with a TL0 user seen as anonymous" do
    let(:user) { Fabricate(:user, trust_level: 0) }
    let(:serializer) { described_class.new(user, scope: Guardian.new, root: false) }
    let(:json) { serializer.as_json }

    it "does not serialize emails" do
      expect(json[:secondary_emails]).to be_nil
      expect(json[:unconfirmed_emails]).to be_nil
    end
  end

  context "as current user" do
    it "serializes emails correctly" do
      user = Fabricate(:user)
      user.user_option.update(dynamic_favicon: true)

      json = described_class.new(user, scope: Guardian.new(user), root: false).as_json
      expect(json[:secondary_emails]).to eq([])
      expect(json[:unconfirmed_emails]).to eq([])
    end
  end

  context "as different user" do
    let(:user) { Fabricate(:user, trust_level: 0) }
    let(:user2) { Fabricate(:user, trust_level: 1) }

    it "does not serialize emails" do
      json = described_class.new(user, scope: Guardian.new(user2), root: false).as_json
      expect(json[:secondary_emails]).to be_nil
      expect(json[:unconfirmed_emails]).to be_nil
    end
  end

  describe "#pending_posts_count" do
    let(:user) { Fabricate(:user) }
    let(:serializer) { described_class.new(user, scope: guardian, root: false) }
    let(:json) { serializer.as_json }

    context "when guardian is another user" do
      let(:guardian) { Guardian.new(other_user) }

      context "when other user is not a staff member" do
        let(:other_user) { Fabricate(:user) }

        it "does not serialize pending_posts_count" do
          expect(json.keys).not_to include :pending_posts_count
        end
      end

      context "when other user is a staff member" do
        let(:other_user) { Fabricate(:user, moderator: true) }

        it "serializes pending_posts_count" do
          expect(json[:pending_posts_count]).to eq 0
        end
      end
    end

    context "when guardian is the current user" do
      let(:guardian) { Guardian.new(user) }

      it "serializes pending_posts_count" do
        expect(json[:pending_posts_count]).to eq 0
      end

      context "when the user is in a group with PMs enabled" do
        before { SiteSetting.personal_message_enabled_groups = Group::AUTO_GROUPS[:everyone] }

        it "can_send_private_message_to_user is true" do
          expect(json[:can_send_private_message_to_user]).to eq true
        end
      end

      context "when the user is not in a group with PMs enabled" do
        before { SiteSetting.personal_message_enabled_groups = Group::AUTO_GROUPS[:moderators] }

        it "can_send_private_message_to_user is false" do
          expect(json[:can_send_private_message_to_user]).to eq false
        end
      end
    end
  end

  describe "#status" do
    fab!(:user_status)
    fab!(:user) { Fabricate(:user, user_status: user_status) }
    let(:serializer) { described_class.new(user, scope: Guardian.new(user), root: false) }

    it "adds user status when enabled" do
      SiteSetting.enable_user_status = true

      json = serializer.as_json

      expect(json[:status]).to_not be_nil do |status|
        expect(status.description).to eq(user_status.description)
        expect(status.emoji).to eq(user_status.emoji)
      end
    end

    it "doesn't add user status when disabled" do
      SiteSetting.enable_user_status = false
      json = serializer.as_json
      expect(json.keys).not_to include :status
    end

    it "doesn't add expired user status" do
      SiteSetting.enable_user_status = true

      user.user_status.ends_at = 1.minutes.ago
      serializer = described_class.new(user, scope: Guardian.new(user), root: false)
      json = serializer.as_json

      expect(json.keys).not_to include :status
    end

    it "doesn't return status if user doesn't have it set" do
      SiteSetting.enable_user_status = true

      user.clear_status!
      user.reload
      json = serializer.as_json

      expect(json.keys).not_to include :status
    end
  end
end
