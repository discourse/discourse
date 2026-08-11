# frozen_string_literal: true

RSpec.describe AdminDashboardSiteTrafficExplorer::Fetch do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:start_date) }
    it { is_expected.to validate_presence_of(:end_date) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    let(:params) { { start_date: "2026-05-01", end_date: "2026-05-12" } }
    let(:dependencies) { {} }
    let(:traffic) do
      { partial_data: false, summary: { "pageviews" => 3 }, series: [], dimensions: {} }
    end

    before { AdminDashboardSiteTrafficExplorer.stubs(:call).returns(traffic) }

    context "when the contract is invalid" do
      let(:params) { super().except(:start_date) }

      it { is_expected.to fail_a_contract }
    end

    context "when the query is canceled by Active Record" do
      before { AdminDashboardSiteTrafficExplorer.stubs(:call).raises(ActiveRecord::QueryCanceled) }

      it { is_expected.to fail_with_exception(ActiveRecord::QueryCanceled) }
    end

    context "when the query is canceled by PostgreSQL" do
      before { AdminDashboardSiteTrafficExplorer.stubs(:call).raises(PG::QueryCanceled) }

      it { is_expected.to fail_with_exception(PG::QueryCanceled) }
    end

    context "when the query succeeds" do
      it { is_expected.to run_successfully }

      it "returns the traffic result" do
        expect(result.traffic).to eq(traffic)
      end
    end
  end
end
