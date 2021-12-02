# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CurrentUserSerializer do
  subject(:serializer) { described_class.new(user, scope: guardian, root: false) }

  let(:guardian) { Guardian.new }

  context "when SSO is not enabled" do
    fab!(:user) { Fabricate(:user) }

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

  context "#top_category_ids" do
    fab!(:user) { Fabricate(:user) }
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

  context "#muted_tag_ids" do
    fab!(:user) { Fabricate(:user) }
    fab!(:tag) { Fabricate(:tag) }
    let!(:tag_user) do
      TagUser.create!(user_id: user.id,
                      notification_level: TagUser.notification_levels[:muted],
                      tag_id: tag.id
                     )
    end

    it 'include muted tag ids' do
      payload = serializer.as_json
      expect(payload[:muted_tag_ids]).to eq([tag.id])
    end
  end

  context "#second_factor_enabled" do
    fab!(:user) { Fabricate(:user) }
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

  context "#groups" do
    fab!(:user) { Fabricate(:user) }

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

  context "#has_topic_draft" do
    fab!(:user) { Fabricate(:user) }

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

  context "#can_review" do
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
end
