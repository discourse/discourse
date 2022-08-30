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
    fab!(:tag_1) { Fabricate(:tag, name: "foo") }
    fab!(:tag_2) { Fabricate(:tag, name: "bar") }
    fab!(:hidden_tag) { Fabricate(:tag, name: "secret") }
    fab!(:staff_tag_group) { Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: ["secret"]) }
    let(:tag_sidebar_section_link) { Fabricate(:tag_sidebar_section_link, user: user) }
    let(:tag_sidebar_section_link_2) { Fabricate(:tag_sidebar_section_link, user: user) }

    it "is not included when experimental sidebar has not been enabled" do
      tag_sidebar_section_link
      SiteSetting.enable_experimental_sidebar_hamburger = false
      SiteSetting.tagging_enabled = true

      json = serializer.as_json

      expect(json[:sidebar_tags]).to eq(nil)
    end

    it "is not included when tagging has not been enabled" do
      tag_sidebar_section_link
      SiteSetting.enable_experimental_sidebar_hamburger = true
      SiteSetting.tagging_enabled = false

      json = serializer.as_json

      expect(json[:sidebar_tags]).to eq(nil)
    end

    it "is present when experimental sidebar and tagging has been enabled" do
      tag_sidebar_section_link
      SiteSetting.enable_experimental_sidebar_hamburger = true
      SiteSetting.tagging_enabled = true

      tag_sidebar_section_link_2.linkable.update!(pm_topic_count: 5, topic_count: 0)

      json = serializer.as_json

      expect(json[:sidebar_tags]).to contain_exactly(
        { name: tag_sidebar_section_link.linkable.name, pm_only: false },
        { name: tag_sidebar_section_link_2.linkable.name, pm_only: true }
      )
    end

    it 'includes visible default sidebar tags' do
      SiteSetting.enable_experimental_sidebar_hamburger = true
      SiteSetting.tagging_enabled = true
      SiteSetting.default_sidebar_tags = "foo|bar|secret"

      json = serializer.as_json

      expect(json[:sidebar_tags]).to eq([
        { name: "foo", pm_only: false },
        { name: "bar", pm_only: false }
      ])
    end

    it 'includes tags choosen by user' do
      SiteSetting.enable_experimental_sidebar_hamburger = true
      SiteSetting.tagging_enabled = true
      SiteSetting.default_sidebar_tags = "foo|bar|secret"
      tag_sidebar_section_link = Fabricate(:tag_sidebar_section_link, user: user)

      json = serializer.as_json

      expect(json[:sidebar_tags]).to eq([
        { name: tag_sidebar_section_link.linkable.name, pm_only: false }
      ])
    end
  end

  describe '#sidebar_category_ids' do
    fab!(:category) { Fabricate(:category) }
    fab!(:category_2) { Fabricate(:category) }
    fab!(:private_category) { Fabricate(:private_category, group: Fabricate(:group)) }
    let(:category_sidebar_section_link) { Fabricate(:category_sidebar_section_link, user: user) }
    let(:category_sidebar_section_link_2) { Fabricate(:category_sidebar_section_link, user: user) }

    it "is not included when SiteSeting.enable_experimental_sidebar_hamburger is false" do
      category_sidebar_section_link
      SiteSetting.enable_experimental_sidebar_hamburger = false

      json = serializer.as_json

      expect(json[:sidebar_category_ids]).to eq(nil)
    end

    it "is not included when experimental sidebar has not been enabled" do
      category_sidebar_section_link
      SiteSetting.enable_experimental_sidebar_hamburger = false

      json = serializer.as_json

      expect(json[:sidebar_category_ids]).to eq(nil)
    end

    it 'includes visible default sidebar categories' do
      SiteSetting.enable_experimental_sidebar_hamburger = true
      SiteSetting.default_sidebar_categories = "#{category.id}|#{category_2.id}|#{private_category.id}"

      json = serializer.as_json
      expect(json[:sidebar_category_ids]).to eq([category.id, category_2.id])
    end

    it 'includes categories choosen by user' do
      SiteSetting.enable_experimental_sidebar_hamburger = true
      SiteSetting.default_sidebar_categories = "#{category.id}|#{category_2.id}|#{private_category.id}"

      category_sidebar_section_link
      category_sidebar_section_link_2

      json = serializer.as_json
      expect(json[:sidebar_category_ids]).to eq([category_sidebar_section_link.linkable.id, category_sidebar_section_link_2.linkable.id])
    end
  end

  describe "#likes_notifications_disabled" do
    it "is true if the user disables likes notifications" do
      user.user_option.update!(like_notification_frequency: UserOption.like_notification_frequency_type[:never])
      expect(serializer.as_json[:likes_notifications_disabled]).to eq(true)
    end

    it "is false if the user doesn't disable likes notifications" do
      user.user_option.update!(like_notification_frequency: UserOption.like_notification_frequency_type[:always])
      expect(serializer.as_json[:likes_notifications_disabled]).to eq(false)
      user.user_option.update!(like_notification_frequency: UserOption.like_notification_frequency_type[:first_time_and_daily])
      expect(serializer.as_json[:likes_notifications_disabled]).to eq(false)
      user.user_option.update!(like_notification_frequency: UserOption.like_notification_frequency_type[:first_time])
      expect(serializer.as_json[:likes_notifications_disabled]).to eq(false)
    end
  end
end
