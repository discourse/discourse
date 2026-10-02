# frozen_string_literal: true

RSpec.describe DiscourseRewind::Action::TimeOfDayActivity do
  fab!(:user)

  describe ".call" do
    it "returns nothing when the user has no activity" do
      expect(call_report).to be_nil
    end

    it "returns the hour the user posts the most in their timezone during the year" do
      user.user_option.update!(timezone: "Eastern Time (US & Canada)")
      Fabricate(:post, user:, created_at: Time.utc(2021, 6, 1, 14))
      2.times { Fabricate(:post, user:, created_at: Time.utc(2020, 6, 1, 20)) }

      expect(call_report[:data]).to eq(
        activity_by_hour: Array.new(24, 0).tap { _1[10] = 1 },
        most_active_hour: 10,
      )
    end
  end
end
