# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CurrentUserSerializer do
  context "when SSO is not enabled" do
    fab!(:user) { Fabricate(:user) }
    let :serializer do
      CurrentUserSerializer.new(user, scope: Guardian.new, root: false)
    end

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

    let :serializer do
      CurrentUserSerializer.new(user, scope: Guardian.new, root: false)
    end

    it "should include the external_id" do
      SiteSetting.discourse_connect_url = "http://example.com/discourse_sso"
      SiteSetting.discourse_connect_secret = "12345678910"
      SiteSetting.enable_discourse_connect = true
      payload = serializer.as_json
      expect(payload[:external_id]).to eq("12345")
    end
  end

  context "#top_category_ids" do
    fab!(:user) { Fabricate(:user) }
    fab!(:category1) { Fabricate(:category) }
    fab!(:category2) { Fabricate(:category) }
    fab!(:category3) { Fabricate(:category) }
    let :serializer do
      CurrentUserSerializer.new(user, scope: Guardian.new, root: false)
    end

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

  context "#muted_tag_ids" do
    fab!(:user) { Fabricate(:user) }
    fab!(:tag) { Fabricate(:tag) }
    let!(:tag_user) do
      TagUser.create!(user_id: user.id,
                      notification_level: TagUser.notification_levels[:muted],
                      tag_id: tag.id
                     )
    end
    let :serializer do
      CurrentUserSerializer.new(user, scope: Guardian.new, root: false)
    end

    it 'include muted tag ids' do
      payload = serializer.as_json
      expect(payload[:muted_tag_ids]).to eq([tag.id])
    end
  end

  context "#second_factor_enabled" do
    fab!(:user) { Fabricate(:user) }
    let :serializer do
      CurrentUserSerializer.new(user, scope: Guardian.new(user), root: false)
    end
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

  context "#groups" do
    fab!(:member) { Fabricate(:user) }
    let :serializer do
      CurrentUserSerializer.new(member, scope: Guardian.new, root: false)
    end

    it "should only show visible groups" do
      Fabricate.build(:group, visibility_level: Group.visibility_levels[:public])
      hidden_group = Fabricate.build(:group, visibility_level: Group.visibility_levels[:owners])
      public_group = Fabricate.build(:group, visibility_level: Group.visibility_levels[:public], name: "UppercaseGroupName")
      hidden_group.add(member)
      hidden_group.save!
      public_group.add(member)
      public_group.save!
      payload = serializer.as_json

      expect(payload[:groups]).to contain_exactly(
        { id: public_group.id, name: public_group.name, has_messages: false }
      )
    end
  end

  context "#has_topic_draft" do
    fab!(:user) { Fabricate(:user) }
    let :serializer do
      CurrentUserSerializer.new(user, scope: Guardian.new, root: false)
    end

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

  context '#can_review' do
    it 'return false for regular users' do
      serializer = serializer(Fabricate(:user))
      payload = serializer.as_json

      expect(payload[:can_review]).to eq(false)
    end

    it 'returns trus for staff' do
      serializer = serializer(Fabricate(:admin))
      payload = serializer.as_json

      expect(payload[:can_review]).to eq(true)
    end

    def serializer(user)
      CurrentUserSerializer.new(user, scope: Guardian.new(user), root: false)
    end
  end

  context "#recent_searches" do
    fab!(:user) { Fabricate(:user) }
    let :serializer do
      CurrentUserSerializer.new(user, scope: Guardian.new(user), root: false)
    end

    it "is not included when search logging is disabled" do
      SiteSetting.log_search_queries = false

      payload = serializer.as_json
      expect(payload).not_to have_key(:recent_searches)
    end

    it "has the users last few searches" do
      SiteSetting.log_search_queries = true
      Search.execute("something", user_id: user.id, search_type: :header, ip_address: '192.168.0.1')
      Search.execute("last keyword", user_id: user.id, search_type: :header, ip_address: '192.168.0.1')

      payload = serializer.as_json
      expect(payload[:recent_searches]).to eq(["last keyword", "something"])
    end

    it "respects oldest_search_log_date user option" do
      SiteSetting.log_search_queries = true
      SearchLog.create!(
        term: "old one",
        user_id: user.id,
        search_type: 1,
        ip_address: '192.168.0.1',
        created_at: 5.minutes.ago
      )
      SearchLog.create!(
        term: "also old",
        user_id: user.id,
        search_type: 1,
        ip_address: '192.168.0.1',
        created_at: 15.minutes.ago
      )

      user.user_option.oldest_search_log_date = 10.seconds.ago
      user.user_option.save
      user.reload

      SearchLog.create!(
        term: "new search",
        user_id: user.id,
        search_type: 1,
        ip_address: '192.168.0.1',
        created_at: 2.seconds.ago
      )

      payload = serializer.as_json
      expect(payload[:recent_searches]).to eq(["new search"])
    end
  end
end
