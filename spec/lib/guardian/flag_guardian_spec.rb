# frozen_string_literal: true

RSpec.describe FlagGuardian do
  fab!(:user)
  fab!(:admin)
  fab!(:flag)

  describe "#can_edit_flag?" do
    it "returns true for admin and false for regular user" do
      expect(Guardian.new(admin).can_edit_flag?(flag)).to eq(true)
      expect(Guardian.new(user).can_edit_flag?(flag)).to eq(false)
    end

    it "returns false when flag is system" do
      flag.update!(id: 5)
      Fabricate(:post_action, post_action_type_id: flag.id)
      expect(Guardian.new(admin).can_edit_flag?(flag)).to eq(false)
    end

    it "returns false when flag was already used" do
      Fabricate(:post_action, post_action_type_id: flag.id)
      expect(Guardian.new(admin).can_edit_flag?(flag)).to eq(false)
    end
  end
end
