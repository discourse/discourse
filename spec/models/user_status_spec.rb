# frozen_string_literal: true

RSpec.describe UserStatus do
  fab!(:user) { Fabricate(:user) }

  describe "validations" do
    it "is invalid when ends_at is before set_at" do
      freeze_time
      user_status = UserStatus.new(user: user, set_at: Time.zone.now, ends_at: 1.hour.ago)
      user_status.valid?
      expect(user_status.errors[:ends_at]).to be_present
    end
  end
end
