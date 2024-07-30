# frozen_string_literal: true

RSpec.describe FlagGuardian do
  fab!(:user)
  fab!(:admin)
  fab!(:moderator)

  after(:each) { Flag.reset_flag_settings! }

  describe "#can_edit_flag?" do
    it "returns true for admin and false for moderator and regular user" do
      flag = Fabricate(:flag)
      expect(Guardian.new(admin).can_edit_flag?(flag)).to eq(true)
      expect(Guardian.new(moderator).can_edit_flag?(flag)).to eq(false)
      expect(Guardian.new(user).can_edit_flag?(flag)).to eq(false)
      flag.destroy!
    end

    it "returns false when flag is system" do
      expect(Guardian.new(admin).can_edit_flag?(Flag.system.first)).to eq(false)
    end

    it "returns false when flag was already used with post action" do
      flag = Fabricate(:flag)
      Fabricate(:post_action, post_action_type_id: flag.id)
      expect(Guardian.new(admin).can_edit_flag?(flag)).to eq(false)
      flag.destroy!
    end

    it "returns false when flag was already used with reviewable" do
      flag = Fabricate(:flag)
      Fabricate(:reviewable_score, reviewable_score_type: flag.id)
      expect(Guardian.new(admin).can_edit_flag?(flag)).to eq(false)
      flag.destroy!
    end
  end

  describe "#can_toggle_flag?" do
    it "returns true for admin and false for regular user" do
      expect(Guardian.new(admin).can_toggle_flag?).to eq(true)
      expect(Guardian.new(user).can_toggle_flag?).to eq(false)
    end
  end

  describe "#can_reorder_flag?" do
    it "returns true for admin and false for regular user and notify_user" do
      expect(Guardian.new(admin).can_reorder_flag?(Flag.system.last)).to eq(true)
      expect(
        Guardian.new(admin).can_reorder_flag?(Flag.system.find_by(name_key: "notify_user")),
      ).to eq(false)
      expect(Guardian.new(user).can_reorder_flag?(Flag.system.last)).to eq(false)
    end
  end
end
