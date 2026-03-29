# frozen_string_literal: true

RSpec.describe UserOption do
  fab!(:user)

  describe "boost_notifications_level" do
    it "allows valid values" do
      [0, 1, 2].each do |level|
        user.user_option.boost_notifications_level = level
        expect(user.user_option).to be_valid
      end
    end

    it "rejects invalid values" do
      user.user_option.boost_notifications_level = 99
      expect(user.user_option).not_to be_valid
    end
  end
end
