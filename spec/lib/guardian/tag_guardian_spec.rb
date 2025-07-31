# frozen_string_literal: true

RSpec.describe TagGuardian do
  fab!(:user)
  fab!(:admin)
  fab!(:tag)
  fab!(:trust_level_0)
  fab!(:trust_level_1)
  fab!(:trust_level_2)
  fab!(:trust_level_3)

  ###### VISIBILITY ######

  describe "#can_see_tag?" do
    it "returns true for everyone" do
      expect(Guardian.new(nil).can_see_tag?(anything)).to be_truthy
    end
  end

  ###### CREATION ######

  describe "#can_create_tag?" do
    it "returns false when tagging is disabled" do
      SiteSetting.tagging_enabled = false

      expect(Guardian.new(admin).can_create_tag?).to be_falsey
    end

    it "returns false when user is not in an allowed group" do
      expect(Guardian.new(trust_level_2).can_create_tag?).to be_falsey
    end

    it "returns true when user is in an allowed group" do
      expect(Guardian.new(trust_level_3).can_create_tag?).to be_truthy
    end
  end

  ###### EDITING ######

  describe "#can_edit_tag?" do
    it "returns false when tagging is disabled" do
      SiteSetting.tagging_enabled = false

      expect(Guardian.new(admin).can_edit_tag?(tag)).to be_falsey
    end

    it "returns false when user is not in an allowed group" do
      SiteSetting.edit_tags_allowed_groups = "1|2|13"
      expect(Guardian.new(trust_level_2).can_edit_tag?(tag)).to be_falsey
    end

    it "returns true when user is in an allowed group" do
      SiteSetting.edit_tags_allowed_groups = "1|2|13"
      expect(Guardian.new(trust_level_3).can_edit_tag?(tag)).to be_truthy
    end
  end

  ###### TAGGING ######

  describe "#can_tag_topics?" do
    it "returns false when tagging is disabled" do
      SiteSetting.tagging_enabled = false

      expect(Guardian.new(admin).can_create_tag?).to be_falsey
    end

    it "returns false when user is not in an allowed group" do
      SiteSetting.tag_topic_allowed_groups = "1|2|11"

      expect(Guardian.new(trust_level_0).can_tag_topics?).to be_falsey
    end

    it "returns true when user is in an allowed group" do
      expect(Guardian.new(trust_level_1).can_tag_topics?).to be_truthy
    end
  end

  describe "#can_tag_pms?" do
    it "returns false when tagging is disabled" do
      SiteSetting.tagging_enabled = false

      expect(Guardian.new(admin).can_tag_pms?).to be_falsey
    end

    it "returns true when the actor is the system user" do
      expect(Guardian.new(Discourse.system_user).can_tag_pms?).to be_truthy
    end

    it "returns false for a guest user" do
      expect(Guardian.new(nil).can_tag_pms?).to be_falsey
    end

    it "returns false when user is not in an allowed group" do
      SiteSetting.pm_tags_allowed_for_groups = "1|2|11"

      expect(Guardian.new(trust_level_0).can_tag_pms?).to be_falsey
    end

    it "returns true when user is in an allowed group" do
      SiteSetting.pm_tags_allowed_for_groups = "1|2|11"

      expect(Guardian.new(trust_level_1).can_tag_pms?).to be_truthy
    end
  end

  ###### ADMIN ######

  describe "#can_admin_tags?" do
    it "returns false when tagging is disabled" do
      SiteSetting.tagging_enabled = false

      expect(Guardian.new(admin).can_admin_tags?).to be_falsey
    end

    it "returns false for a regular user" do
      expect(Guardian.new(user).can_admin_tags?).to be_falsey
    end

    it "returns true for a staff user" do
      expect(Guardian.new(admin).can_admin_tags?).to be_truthy
    end
  end

  describe "#can_admin_tag_groups?" do
    it "returns false when tagging is disabled" do
      SiteSetting.tagging_enabled = false

      expect(Guardian.new(admin).can_admin_tag_groups?).to be_falsey
    end

    it "returns false for a regular user" do
      expect(Guardian.new(user).can_admin_tag_groups?).to be_falsey
    end

    it "returns true for a staff user" do
      expect(Guardian.new(admin).can_admin_tag_groups?).to be_truthy
    end
  end
end
