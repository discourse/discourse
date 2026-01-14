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
    fab!(:user) { Fabricate(:user, user_status:) }

    def serialize_status
      described_class.new(user, scope: Guardian.new(user), root: false).as_json[:status]
    end

    context "when user status is disabled" do
      before { SiteSetting.enable_user_status = false }

      it "doesn't include status" do
        expect(serialize_status).to be_nil
      end
    end

    context "when user status is enabled" do
      before { SiteSetting.enable_user_status = true }

      it "includes status" do
        expect(serialize_status).to be_present
        expect(serialize_status[:description]).to eq(user_status.description)
        expect(serialize_status[:emoji]).to eq(user_status.emoji)
      end

      it "doesn't include expired status" do
        user.user_status.ends_at = 1.minute.ago
        expect(serialize_status).to be_nil
      end

      it "doesn't include status if user doesn't have it set" do
        user.clear_status!
        user.reload
        expect(serialize_status).to be_nil
      end
    end
  end

  describe "#featured_topic" do
    fab!(:user)
    fab!(:featured_topic, :topic)

    before { user.user_profile.update(featured_topic_id: featured_topic.id) }

    it "includes the featured topic" do
      serializer = described_class.new(user, scope: Guardian.new(user), root: false)
      json = serializer.as_json

      expect(json[:featured_topic]).to_not be_nil
      expect(json[:featured_topic][:id]).to eq(featured_topic.id)
      expect(json[:featured_topic][:title]).to eq(featured_topic.title)
      expect(json[:featured_topic].keys).to contain_exactly(
        :id,
        :title,
        :fancy_title,
        :slug,
        :posts_count,
      )
    end
  end

  describe "#user_fields" do
    fab!(:user)

    it "includes the user field" do
      user_field = Fabricate(:user_field, show_on_profile: true, show_on_user_card: true)
      user.set_user_field(user_field.id, "foo")

      serializer = described_class.new(user, scope: Guardian.new(user), root: false)
      json = serializer.as_json

      expect(json[:user_fields]).to_not be_nil
      expect(json[:user_fields][user_field.id.to_s]).to eq("foo")
    end

    it "converts confirm fields to boolean" do
      user_field =
        Fabricate(
          :user_field,
          field_type: "confirm",
          show_on_profile: true,
          show_on_user_card: true,
        )

      test_values = { "true" => true, "T" => true, "1" => true, "false" => false, "lol" => false }

      test_values.each do |value, expected|
        user.set_user_field(user_field.id, value)
        serializer = described_class.new(user, scope: Guardian.new(user), root: false)
        json = serializer.as_json

        expect(json[:user_fields]).to_not be_nil
        expect(json[:user_fields][user_field.id.to_s]).to eq(expected)
      end
    end
  end
end
