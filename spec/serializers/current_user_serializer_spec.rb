# frozen_string_literal: true

RSpec.describe CurrentUserSerializer do
  fab!(:user)
  subject(:serializer) { described_class.new(user, scope: guardian, root: false) }

  let(:guardian) { Guardian.new(user) }

  context "when SSO is not enabled" do
    it "should not include the external_id field" do
      payload = serializer.as_json
      expect(payload).not_to have_key(:external_id)
    end
  end

  context "when SSO is enabled" do
    let :user do
      user = Fabricate(:user)
      SingleSignOnRecord.create!(user_id: user.id, external_id: "12345", last_payload: "")
      user
    end

    it "should include the external_id" do
      SiteSetting.discourse_connect_url = "http://example.com/discourse_sso"
      SiteSetting.discourse_connect_secret = "12345678910"
      SiteSetting.enable_discourse_connect = true
      payload = serializer.as_json
      expect(payload[:external_id]).to eq("12345")
    end
  end

  describe "#top_category_ids" do
    fab!(:category1) { Fabricate(:category) }
    fab!(:category2) { Fabricate(:category) }
    fab!(:category3) { Fabricate(:category) }

    it "should include empty top_category_ids array" do
      payload = serializer.as_json
      expect(payload[:top_category_ids]).to eq([])
    end

    it "should include correct id in top_category_ids array" do
      _category = Category.first
      CategoryUser.create!(
        user_id: user.id,
        category_id: category1.id,
        notification_level: CategoryUser.notification_levels[:tracking],
      )

      CategoryUser.create!(
        user_id: user.id,
        category_id: category2.id,
        notification_level: CategoryUser.notification_levels[:watching],
      )

      CategoryUser.create!(
        user_id: user.id,
        category_id: category3.id,
        notification_level: CategoryUser.notification_levels[:regular],
      )

      payload = serializer.as_json
      expect(payload[:top_category_ids]).to eq([category2.id, category1.id])
    end
  end

  describe "#muted_tag" do
    fab!(:tag)

    let!(:tag_user) do
      TagUser.create!(
        user_id: user.id,
        notification_level: TagUser.notification_levels[:muted],
        tag_id: tag.id,
      )
    end

    it "includes muted tag names" do
      payload = serializer.as_json
      expect(payload[:muted_tags]).to eq([tag.name])
    end
  end

  describe "#second_factor_enabled" do
    let(:guardian) { Guardian.new(user) }
    let(:json) { serializer.as_json }

    it "is false by default" do
      expect(json[:second_factor_enabled]).to eq(false)
    end

    context "when totp enabled" do
      before { User.any_instance.stubs(:totp_enabled?).returns(true) }

      it "is true" do
        expect(json[:second_factor_enabled]).to eq(true)
      end
    end

    context "when security_keys enabled" do
      before { User.any_instance.stubs(:security_keys_enabled?).returns(true) }

      it "is true" do
        expect(json[:second_factor_enabled]).to eq(true)
      end
    end
  end

  describe "#groups" do
    it "should only show visible groups" do
      Fabricate.build(:group, visibility_level: Group.visibility_levels[:public])
      hidden_group = Fabricate.build(:group, visibility_level: Group.visibility_levels[:owners])
      public_group =
        Fabricate.build(
          :group,
          visibility_level: Group.visibility_levels[:public],
          name: "UppercaseGroupName",
        )
      hidden_group.add(user)
      hidden_group.save!
      public_group.add(user)
      public_group.save!
      payload = serializer.as_json

      expect(payload[:groups]).to contain_exactly(
        { id: public_group.id, name: public_group.name, has_messages: false },
      )
    end
  end

  describe "#can_ignore_users" do
    let(:guardian) { Guardian.new(user) }
    let(:payload) { serializer.as_json }

    context "when user is a regular one" do
      let(:user) { Fabricate(:user) }

      it "return false for regular users" do
        expect(payload[:can_ignore_users]).to eq(false)
      end
    end

    context "when user is a staff member" do
      let(:user) { Fabricate(:moderator) }

      it "returns true" do
        expect(payload[:can_ignore_users]).to eq(true)
      end
    end
  end

  describe "#can_review" do
    let(:guardian) { Guardian.new(user) }
    let(:payload) { serializer.as_json }

    context "when user is a regular one" do
      let(:user) { Fabricate(:user) }

      it "return false for regular users" do
        expect(payload[:can_review]).to eq(false)
      end
    end

    context "when user is a staff member" do
      let(:user) { Fabricate(:admin) }

      it "returns true" do
        expect(payload[:can_review]).to eq(true)
      end
    end
  end

  describe "#pending_posts_count" do
    subject(:pending_posts_count) { serializer.pending_posts_count }

    let(:user) { Fabricate(:user) }

    before { user.user_stat.pending_posts_count = 3 }

    it "serializes 'pending_posts_count'" do
      expect(pending_posts_count).to eq 3
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

  describe "#likes_notifications_disabled" do
    it "is true if the user disables likes notifications" do
      user.user_option.update!(
        like_notification_frequency: UserOption.like_notification_frequency_type[:never],
      )
      expect(serializer.as_json[:user_option][:likes_notifications_disabled]).to eq(true)
    end

    it "is false if the user doesn't disable likes notifications" do
      user.user_option.update!(
        like_notification_frequency: UserOption.like_notification_frequency_type[:always],
      )
      expect(serializer.as_json[:user_option][:likes_notifications_disabled]).to eq(false)
      user.user_option.update!(
        like_notification_frequency:
          UserOption.like_notification_frequency_type[:first_time_and_daily],
      )
      expect(serializer.as_json[:user_option][:likes_notifications_disabled]).to eq(false)
      user.user_option.update!(
        like_notification_frequency: UserOption.like_notification_frequency_type[:first_time],
      )
      expect(serializer.as_json[:user_option][:likes_notifications_disabled]).to eq(false)
    end
  end

  describe "#associated_account_ids" do
    before do
      UserAssociatedAccount.create(
        user_id: user.id,
        provider_name: "twitter",
        provider_uid: "1",
        info: {
          nickname: "sam",
        },
      )
    end

    it "should not include associated account ids by default" do
      expect(serializer.as_json[:associated_account_ids]).to be_nil
    end

    it "should include associated account ids when site setting enabled" do
      SiteSetting.include_associated_account_ids = true
      expect(serializer.as_json[:associated_account_ids]).to eq({ "twitter" => "1" })
    end
  end

  describe "#new_personal_messages_notifications_count" do
    fab!(:notification) do
      Fabricate(
        :notification,
        user: user,
        read: false,
        notification_type: Notification.types[:private_message],
      )
    end

    it "is included when sidebar is enabled" do
      SiteSetting.navigation_menu = "sidebar"

      expect(serializer.as_json[:new_personal_messages_notifications_count]).to eq(1)
    end
  end

  include_examples "User Sidebar Serializer Attributes", described_class

  describe "#sidebar_sections" do
    fab!(:group)
    fab!(:sidebar_section) { Fabricate(:sidebar_section, user: user) }

    it "eager loads sidebar_urls" do
      custom_sidebar_section_link_1 =
        Fabricate(:custom_sidebar_section_link, user: user, sidebar_section: sidebar_section)

      # warmup
      described_class.new(user, scope: Guardian.new(user), root: false).as_json

      initial_count =
        track_sql_queries do
          serialized = described_class.new(user, scope: Guardian.new(user), root: false).as_json

          expect(serialized[:sidebar_sections].count).to eq(2)

          expect(serialized[:sidebar_sections].last[:links].map { |link| link.id }).to eq(
            [custom_sidebar_section_link_1.linkable.id],
          )
        end.count

      custom_sidebar_section_link_2 =
        Fabricate(:custom_sidebar_section_link, user: user, sidebar_section: sidebar_section)

      final_count =
        track_sql_queries do
          serialized = described_class.new(user, scope: Guardian.new(user), root: false).as_json

          expect(serialized[:sidebar_sections].count).to eq(2)

          expect(serialized[:sidebar_sections].last[:links].map { |link| link.id }).to eq(
            [custom_sidebar_section_link_1.linkable.id, custom_sidebar_section_link_2.linkable.id],
          )
        end.count

      expect(initial_count).to eq(final_count)
    end
  end

  describe "#featured_topic" do
    fab!(:featured_topic) { Fabricate(:topic) }

    before { user.user_profile.update!(featured_topic_id: featured_topic.id) }

    it "includes the featured topic" do
      payload = serializer.as_json

      expect(payload[:featured_topic]).to_not be_nil
      expect(payload[:featured_topic][:id]).to eq(featured_topic.id)
      expect(payload[:featured_topic][:title]).to eq(featured_topic.title)
      expect(payload[:featured_topic].keys).to contain_exactly(
        :id,
        :title,
        :fancy_title,
        :slug,
        :posts_count,
      )
    end
  end
end
