# frozen_string_literal: true

require 'rails_helper'

describe BasicPostSerializer do

  context "name" do
    let(:user) { Fabricate.build(:user) }
    let(:post) { Fabricate.build(:post, user: user) }
    let(:serializer) { BasicPostSerializer.new(post, scope: Guardian.new, root: false) }
    let(:json) { serializer.as_json }

    it "returns the name it when `enable_names` is true" do
      SiteSetting.enable_names = true
      expect(json[:name]).to be_present
    end

    it "doesn't return the name it when `enable_names` is false" do
      SiteSetting.enable_names = false
      expect(json[:name]).to be_blank
    end

  end

  context "cooked" do
    it "includes membership requests" do
      user = Fabricate(:user)
      member = Fabricate(:user)
      owner = Fabricate(:user)

      group = Fabricate(:group)
      group.add(member)
      group.add_owner(owner)

      post = Fabricate(:post, custom_fields: { requested_group_id: group.id })

      json = BasicPostSerializer.new(post, scope: Guardian.new(user), root: false).as_json
      expect(json[:cooked]).not_to include(I18n.t('groups.request_membership_pm.handle'))

      json = BasicPostSerializer.new(post, scope: Guardian.new(member), root: false).as_json
      expect(json[:cooked]).not_to include(I18n.t('groups.request_membership_pm.handle'))

      json = BasicPostSerializer.new(post, scope: Guardian.new(owner), root: false).as_json
      expect(json[:cooked]).to include(I18n.t('groups.request_membership_pm.handle'))
    end
  end

end
