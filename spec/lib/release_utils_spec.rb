# frozen_string_literal: true

require "release_utils"

RSpec.describe ReleaseUtils do
  describe ".last_tuesday_of_month" do
    subject(:last_tuesday) { described_class.last_tuesday_of_month(date) }

    context "with a month ending mid-week" do
      let(:date) { Date.new(2026, 7) }

      it { is_expected.to eq(Date.new(2026, 7, 28)) }
    end

    context "when the month ends on a Tuesday" do
      let(:date) { Date.new(2026, 6) }

      it { is_expected.to eq(Date.new(2026, 6, 30)) }
    end

    context "when the following month starts on a Tuesday" do
      let(:date) { Date.new(2026, 8) }

      it { is_expected.to eq(Date.new(2026, 8, 25)) }
    end

    context "with a leap February ending on a Tuesday" do
      let(:date) { Date.new(2028, 2) }

      it { is_expected.to eq(Date.new(2028, 2, 29)) }
    end

    context "with December (year rollover)" do
      let(:date) { Date.new(2026, 12) }

      it { is_expected.to eq(Date.new(2026, 12, 29)) }
    end

    context "with a date mid-month" do
      let(:date) { Date.new(2026, 7, 15) }

      it { is_expected.to eq(Date.new(2026, 7, 28)) }
    end
  end
end
