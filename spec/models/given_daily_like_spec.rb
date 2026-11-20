# frozen_string_literal: true

RSpec.describe GivenDailyLike do
  it "no errors without a user" do
    expect { GivenDailyLike.increment_for(nil) }.not_to raise_error
    expect { GivenDailyLike.decrement_for(nil) }.not_to raise_error
  end

  describe ".recalculate!" do
    fab!(:user)

    it "recounts live likes per day and deletes days without any" do
      SiteSetting.max_likes_per_day = 2
      freeze_time
      Fabricate(:like, user:, created_at: 1.day.ago)
      Fabricate(:like, user:)
      Fabricate(:like, user:)
      Fabricate(:like, user:, deleted_at: Time.zone.now)
      Fabricate(:post_action, user:, post_action_type_id: PostActionType.types[:off_topic])
      GivenDailyLike.create!(user:, given_date: 2.days.ago.to_date, likes_given: 5)

      GivenDailyLike.recalculate!([user.id])

      expect(
        GivenDailyLike
          .where(user:)
          .order(:given_date)
          .pluck(:given_date, :likes_given, :limit_reached),
      ).to eq([[1.day.ago.to_date, 1, false], [Date.current, 2, true]])
    end
  end

  context "with a user" do
    fab!(:user)

    def value_for(user_id, date)
      GivenDailyLike.find_for(user_id, date).pluck(:likes_given)[0] || 0
    end

    def limit_reached_for(user_id, date)
      GivenDailyLike.find_for(user_id, date).pluck(:limit_reached)[0] || false
    end

    it "can be incremented and decremented" do
      SiteSetting.max_likes_per_day = 2

      dt = Date.today
      freeze_time dt

      expect(value_for(user.id, dt)).to eq(0)
      expect(limit_reached_for(user.id, dt)).to eq(false)

      GivenDailyLike.increment_for(user.id)
      expect(value_for(user.id, dt)).to eq(1)
      expect(limit_reached_for(user.id, dt)).to eq(false)

      GivenDailyLike.increment_for(user.id)
      expect(value_for(user.id, dt)).to eq(2)
      expect(limit_reached_for(user.id, dt)).to eq(true)

      GivenDailyLike.decrement_for(user.id)
      expect(value_for(user.id, dt)).to eq(1)
      expect(limit_reached_for(user.id, dt)).to eq(false)

      GivenDailyLike.decrement_for(user.id)
      expect(value_for(user.id, dt)).to eq(0)
      expect(limit_reached_for(user.id, dt)).to eq(false)
    end
  end
end
