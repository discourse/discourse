# frozen_string_literal: true

RSpec.describe PostGuardian do
  fab!(:user) { Fabricate(:user) }
  fab!(:anon) { Fabricate(:anonymous) }
  fab!(:admin) { Fabricate(:admin) }
  fab!(:tl3_user) { Fabricate(:trust_level_3) }
  fab!(:tl4_user) { Fabricate(:trust_level_4) }
  fab!(:moderator) { Fabricate(:moderator) }
  fab!(:category) { Fabricate(:category) }
  fab!(:group) { Fabricate(:group) }
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:hidden_post) { Fabricate(:post, topic: topic, hidden: true) }

  describe "#can_see_hidden_post?" do
    it "returns false for anonymous users" do
      expect(Guardian.new(anon).can_see_hidden_post?(hidden_post)).to eq(false)
    end

    it "returns false for TL3 users" do
      expect(Guardian.new(tl3_user).can_see_hidden_post?(hidden_post)).to eq(false)
    end

    it "returns true for TL4 users" do
      expect(Guardian.new(tl4_user).can_see_hidden_post?(hidden_post)).to eq(true)
    end

    it "returns true for staff users" do
      expect(Guardian.new(moderator).can_see_hidden_post?(hidden_post)).to eq(true)
      expect(Guardian.new(admin).can_see_hidden_post?(hidden_post)).to eq(true)
    end
  end

  describe "#is_in_edit_post_groups?" do
    it "returns true if the user is in edit_all_post_groups" do
      group.add(user)
      SiteSetting.edit_all_post_groups = group.id.to_s

      expect(Guardian.new(user).is_in_edit_post_groups?).to eq(true)
    end

    it "returns false if the user is not in edit_all_post_groups" do
      SiteSetting.edit_all_post_groups = Group::AUTO_GROUPS[:trust_level_4]

      expect(Guardian.new(tl3_user).is_in_edit_post_groups?).to eq(false)
    end

    it "returns false if the edit_all_post_groups is empty" do
      SiteSetting.edit_all_post_groups = nil

      expect(Guardian.new(user).is_in_edit_post_groups?).to eq(false)
    end
  end
end
