require 'rails_helper'

RSpec.describe CurrentUserSerializer do
  context "when SSO is not enabled" do
    let(:user) { Fabricate(:user) }
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
      SiteSetting.sso_url = "http://example.com/discourse_sso"
      SiteSetting.sso_secret = "12345678910"
      SiteSetting.enable_sso = true
      payload = serializer.as_json
      expect(payload[:external_id]).to eq("12345")
    end
  end

  context "#top_category_ids" do
    let(:user) { Fabricate(:user) }
    let(:category1) { Fabricate(:category) }
    let(:category2) { Fabricate(:category) }
    let(:category3) { Fabricate(:category) }
    let :serializer do
      CurrentUserSerializer.new(user, scope: Guardian.new, root: false)
    end

    it "should include empty top_category_ids array" do
      payload = serializer.as_json
      expect(payload[:top_category_ids]).to eq([])
    end

    it "should include correct id in top_category_ids array" do
      category = Category.first
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

  context "#groups" do
    let(:member) { Fabricate(:user) }
    let :serializer do
      CurrentUserSerializer.new(member, scope: Guardian.new, root: false)
    end

    it "should only show visible groups" do
      Fabricate.build(:group, visibility_level: Group.visibility_levels[:public])
      hidden_group = Fabricate.build(:group, visibility_level: Group.visibility_levels[:owners])
      public_group = Fabricate.build(:group, visibility_level: Group.visibility_levels[:public])
      hidden_group.add(member)
      hidden_group.save!
      public_group.add(member)
      public_group.save!
      payload = serializer.as_json

      expect(payload[:groups]).to eq([{ id: public_group.id, name: public_group.name }])
    end
  end
end
