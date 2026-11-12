# frozen_string_literal: true

RSpec.describe Jobs::DirectoryRefresh do
  before { Discourse.redis.del(described_class::OLDER_PERIODS_REFRESH_KEY) }

  it "always refreshes the daily period" do
    DirectoryItem.stubs(:refresh_period!)
    DirectoryItem.expects(:refresh_period!).with(:daily).once
    described_class.new.execute({})
  end

  context "when older periods are due for refresh" do
    it "refreshes all non-daily periods" do
      older_periods = DirectoryItem.period_types.keys - [:daily]
      older_periods.each { |p| DirectoryItem.expects(:refresh_period!).with(p).once }
      DirectoryItem.stubs(:refresh_period!).with(:daily)
      described_class.new.execute({})
    end

    it "records the refresh time in Redis" do
      DirectoryItem.stubs(:refresh_period!)
      freeze_time do
        described_class.new.execute({})
        expect(Discourse.redis.get(described_class::OLDER_PERIODS_REFRESH_KEY).to_i).to eq(
          Time.zone.now.to_i,
        )
      end
    end
  end

  context "when older periods were recently refreshed" do
    before { Discourse.redis.set(described_class::OLDER_PERIODS_REFRESH_KEY, 1.hour.ago.to_i) }

    it "does not refresh older periods for a large site" do
      SiteSetting.directory_hourly_refresh_max_users = 0
      DirectoryItem.stubs(:refresh_period!).with(:daily)
      older_periods = DirectoryItem.period_types.keys - [:daily]
      older_periods.each { |p| DirectoryItem.expects(:refresh_period!).with(p).never }
      described_class.new.execute({})
    end

    context "when user count is within the limit" do
      fab!(:user)

      before { SiteSetting.directory_hourly_refresh_max_users = 5 }

      it "refreshes older periods for a small site" do
        older_periods = DirectoryItem.period_types.keys - [:daily]
        older_periods.each { |p| DirectoryItem.expects(:refresh_period!).with(p).once }
        DirectoryItem.stubs(:refresh_period!).with(:daily)
        described_class.new.execute({})
      end
    end

    context "when user count exceeds the limit" do
      fab!(:user_1, :user)
      fab!(:user_2, :user)

      before { SiteSetting.directory_hourly_refresh_max_users = 1 }

      it "does not refresh older periods" do
        DirectoryItem.stubs(:refresh_period!).with(:daily)
        older_periods = DirectoryItem.period_types.keys - [:daily]
        older_periods.each { |p| DirectoryItem.expects(:refresh_period!).with(p).never }
        described_class.new.execute({})
      end
    end
  end
end
