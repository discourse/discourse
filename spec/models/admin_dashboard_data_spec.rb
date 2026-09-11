# frozen_string_literal: true

RSpec.describe AdminDashboardData do
  after { Discourse.redis.flushdb }

  describe ".reports" do
    fab!(:moderator)

    it "returns reports visible to the reader" do
      reports = described_class.reports(%w[signups admin_logins], guardian: moderator.guardian)

      expect(reports.map { |report| report[:type] }).to eq(["signups"])
    end
  end

  describe "stats cache" do
    include_examples "stats cacheable"
  end
end
