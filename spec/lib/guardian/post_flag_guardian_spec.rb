# frozen_string_literal: true

RSpec.describe PostFlagGuardian do
  fab!(:user)
  fab!(:admin)
  fab!(:post_flag)

  describe "#can_edit_custom_flag?" do
    it "returns true for admin and false for regular user" do
      expect(Guardian.new(admin).can_edit_post_flag?(post_flag)).to eq(true)
      expect(Guardian.new(user).can_edit_post_flag?(post_flag)).to eq(false)
    end

    it "returns false when flag is system" do
      post_flag.update!(system: true)
      Fabricate(:post_action, post_action_type_id: post_flag.id)
      expect(Guardian.new(admin).can_edit_post_flag?(post_flag)).to eq(false)
    end

    it "returns false when flag was already used" do
      Fabricate(:post_action, post_action_type_id: post_flag.id)
      expect(Guardian.new(admin).can_edit_post_flag?(post_flag)).to eq(false)
    end
  end
end
