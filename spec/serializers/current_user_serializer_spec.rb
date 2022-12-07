# frozen_string_literal: true

RSpec.describe CurrentUserSerializer do
  fab!(:user) { Fabricate(:user) }
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
      SingleSignOnRecord.create!(user_id: user.id, external_id: '12345', last_payload: '')
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
      CategoryUser.create!(user_id: user.id,
                           category_id: category1.id,
                           notification_level: CategoryUser.notification_levels[:tracking])

      CategoryUser.create!(user_id: user.id,
                           category_id: category2.id,
                           notification_level: CategoryUser.notification_levels[:watching])

      CategoryUser.create!(user_id: user.id,
                           category_id: category3.id,
                           notification_level: CategoryUser.notification_levels[:regular])

      payload = serializer.as_json
      expect(payload[:top_category_ids]).to eq([category2.id, category1.id])
    end
  end

  describe "#muted_tag" do
    fab!(:tag) { Fabricate(:tag) }

    let!(:tag_user) do
      TagUser.create!(
        user_id: user.id,
        notification_level: TagUser.notification_levels[:muted],
        tag_id: tag.id
      )
    end

    it 'includes muted tag names' do
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
      before do
        User.any_instance.stubs(:totp_enabled?).returns(true)
      end

      it "is true" do
        expect(json[:second_factor_enabled]).to eq(true)
      end
    end

    context "when security_keys enabled" do
      before do
        User.any_instance.stubs(:security_keys_enabled?).returns(true)
      end

      it "is true" do
        expect(json[:second_factor_enabled]).to eq(true)
      end
    end
  end

  describe "#groups" do
    it "should only show visible groups" do
      Fabricate.build(:group, visibility_level: Group.visibility_levels[:public])
      hidden_group = Fabricate.build(:group, visibility_level: Group.visibility_levels[:owners])
      public_group = Fabricate.build(:group, visibility_level: Group.visibility_levels[:public], name: "UppercaseGroupName")
      hidden_group.add(user)
      hidden_group.save!
      public_group.add(user)
      public_group.save!
      payload = serializer.as_json

      expect(payload[:groups]).to contain_exactly(
        { id: public_group.id, name: public_group.name, has_messages: false }
      )
    end
  end

  describe "#has_topic_draft" do
    it "is not included by default" do
      payload = serializer.as_json
      expect(payload).not_to have_key(:has_topic_draft)
    end

    it "returns true when user has a draft" do
      Draft.set(user, Draft::NEW_TOPIC, 0, "test1")

      payload = serializer.as_json
      expect(payload[:has_topic_draft]).to eq(true)
    end

    it "clearing a draft removes has_topic_draft from payload" do
      sequence = Draft.set(user, Draft::NEW_TOPIC, 0, "test1")
      Draft.clear(user, Draft::NEW_TOPIC, sequence)

      payload = serializer.as_json
      expect(payload).not_to have_key(:has_topic_draft)
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
    fab!(:user_status) { Fabricate(:user_status) }
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

  describe '#sidebar_tags' do
    fab!(:tag) { Fabricate(:tag, name: "foo") }
    fab!(:pm_tag) { Fabricate(:tag, name: "bar", pm_topic_count: 5, topic_count: 0) }
    fab!(:hidden_tag) { Fabricate(:tag, name: "secret") }
    fab!(:staff_tag_group) { Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: ["secret"]) }
    fab!(:tag_sidebar_section_link) { Fabricate(:tag_sidebar_section_link, user: user, linkable: tag) }
    fab!(:tag_sidebar_section_link_2) { Fabricate(:tag_sidebar_section_link, user: user, linkable: pm_tag) }
    fab!(:tag_sidebar_section_link_3) { Fabricate(:tag_sidebar_section_link, user: user, linkable: hidden_tag) }

    it "is not included when experimental sidebar has not been enabled" do
      SiteSetting.enable_experimental_sidebar_hamburger = false
      SiteSetting.tagging_enabled = true

      json = serializer.as_json

      expect(json[:sidebar_tags]).to eq(nil)
    end

    it "is not included when tagging has not been enabled" do
      SiteSetting.enable_experimental_sidebar_hamburger = true
      SiteSetting.tagging_enabled = false

      json = serializer.as_json

      expect(json[:sidebar_tags]).to eq(nil)
    end

    it "serializes only the tags that the user can see when experimental sidebar and tagging has been enabled" do
      SiteSetting.enable_experimental_sidebar_hamburger = true
      SiteSetting.tagging_enabled = true

      json = serializer.as_json

      expect(json[:sidebar_tags]).to contain_exactly(
        { name: tag.name, pm_only: false },
        { name: pm_tag.name, pm_only: true }
      )

      user.update!(admin: true)

      json = serializer.as_json

      expect(json[:sidebar_tags]).to contain_exactly(
        { name: tag.name, pm_only: false },
        { name: pm_tag.name, pm_only: true },
        { name: hidden_tag.name, pm_only: false }
      )
    end
  end

  describe '#sidebar_category_ids' do
    fab!(:group) { Fabricate(:group) }
    fab!(:category) { Fabricate(:category) }
    fab!(:category_2) { Fabricate(:category) }
    fab!(:private_category) { Fabricate(:private_category, group: group) }
    fab!(:category_sidebar_section_link) { Fabricate(:category_sidebar_section_link, user: user, linkable: category) }
    fab!(:category_sidebar_section_link_2) { Fabricate(:category_sidebar_section_link, user: user, linkable: category_2) }
    fab!(:category_sidebar_section_link_3) { Fabricate(:category_sidebar_section_link, user: user, linkable: private_category) }

    it "is not included when SiteSetting.enable_experimental_sidebar_hamburger is false" do
      category_sidebar_section_link
      SiteSetting.enable_experimental_sidebar_hamburger = false

      json = serializer.as_json

      expect(json[:sidebar_category_ids]).to eq(nil)
    end

    it "is not included when experimental sidebar has not been enabled" do
      SiteSetting.enable_experimental_sidebar_hamburger = false

      json = serializer.as_json

      expect(json[:sidebar_category_ids]).to eq(nil)
    end

    it 'serializes only the categories that the user can see when experimental sidebar and tagging has been enabled"' do
      SiteSetting.enable_experimental_sidebar_hamburger = true

      json = serializer.as_json

      expect(json[:sidebar_category_ids]).to eq([
        category.id,
        category_2.id
      ])

      group.add(user)
      serializer = described_class.new(user, scope: Guardian.new(user), root: false)
      json = serializer.as_json

      expect(json[:sidebar_category_ids]).to eq([
        category.id,
        category_2.id,
        private_category.id
      ])
    end
  end

  describe "#likes_notifications_disabled" do
    it "is true if the user disables likes notifications" do
      user.user_option.update!(like_notification_frequency: UserOption.like_notification_frequency_type[:never])
      expect(serializer.as_json[:user_option][:likes_notifications_disabled]).to eq(true)
    end

    it "is false if the user doesn't disable likes notifications" do
      user.user_option.update!(like_notification_frequency: UserOption.like_notification_frequency_type[:always])
      expect(serializer.as_json[:user_option][:likes_notifications_disabled]).to eq(false)
      user.user_option.update!(like_notification_frequency: UserOption.like_notification_frequency_type[:first_time_and_daily])
      expect(serializer.as_json[:user_option][:likes_notifications_disabled]).to eq(false)
      user.user_option.update!(like_notification_frequency: UserOption.like_notification_frequency_type[:first_time])
      expect(serializer.as_json[:user_option][:likes_notifications_disabled]).to eq(false)
    end
  end

  describe '#redesigned_user_page_nav_enabled' do
    fab!(:group) { Fabricate(:group) }
    fab!(:group2) { Fabricate(:group) }

    it "is false when enable_new_user_profile_nav_groups site setting has not been set" do
      expect(serializer.as_json[:redesigned_user_page_nav_enabled]).to eq(false)
    end

    it 'is false if user does not belong to any of the configured groups in the enable_new_user_profile_nav_groups site setting' do
      SiteSetting.enable_new_user_profile_nav_groups = "#{group.id}|#{group2.id}"

      expect(serializer.as_json[:redesigned_user_page_nav_enabled]).to eq(false)
    end

    it 'is true if user belongs one of the configured groups in the enable_new_user_profile_nav_groups site setting' do
      SiteSetting.enable_new_user_profile_nav_groups = "#{group.id}|#{group2.id}"
      group.add(user)

      expect(serializer.as_json[:redesigned_user_page_nav_enabled]).to eq(true)
    end
  end

  describe '#associated_account_ids' do
    before do
      UserAssociatedAccount.create(user_id: user.id, provider_name: "twitter", provider_uid: "1", info: { nickname: "sam" })
    end

    it 'should not include associated account ids by default' do
      expect(serializer.as_json[:associated_account_ids]).to be_nil
    end

    it 'should include associated account ids when site setting enabled' do
      SiteSetting.include_associated_account_ids = true
      expect(serializer.as_json[:associated_account_ids]).to eq({ "twitter" => "1" })
    end
  end

  describe "#sidebar_list_destination" do
    it "returns choosen value or default" do
      expect(serializer.as_json[:sidebar_list_destination]).to eq(SiteSetting.default_sidebar_list_destination)

      user.user_option.update!(sidebar_list_destination: "unread_new")
      expect(serializer.as_json[:sidebar_list_destination]).to eq("unread_new")
    end
  end

  describe "#new_personal_messages_notifications_count" do
    fab!(:notification) { Fabricate(:notification, user: user, read: false, notification_type: Notification.types[:private_message]) }

    it "isn't included when enable_experimental_sidebar_hamburger is disabled" do
      SiteSetting.enable_experimental_sidebar_hamburger = false
      expect(serializer.as_json[:new_personal_messages_notifications_count]).to be_nil
    end

    it "is included when enable_experimental_sidebar_hamburger is enabled" do
      SiteSetting.enable_experimental_sidebar_hamburger = true
      expect(serializer.as_json[:new_personal_messages_notifications_count]).to eq(1)
    end
  end

  include_examples "#display_sidebar_tags", described_class
end
