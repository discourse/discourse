# frozen_string_literal: true

RSpec.describe DiscourseRssPolling::RssFeed::SetEnabled do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_inclusion_of(:enabled).in_array([true, false, "true", "false"]) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:rss_feed)

    let(:enabled) { false }
    let(:params) { { id: rss_feed.id, enabled: } }
    let(:dependencies) { { guardian: admin.guardian } }

    context "when the contract is invalid" do
      let(:enabled) { "maybe" }

      it { is_expected.to fail_a_contract }
    end

    context "when the feed does not exist" do
      let(:params) { { id: -1, enabled: } }

      it { is_expected.to fail_to_find_a_model(:rss_feed) }
    end

    context "when disabling an enabled feed" do
      it { is_expected.to run_successfully }

      it "disables the feed" do
        expect { result }.to change { rss_feed.reload.enabled }.from(true).to(false)
      end

      it "logs the change as a staff action" do
        expect { result }.to change { UserHistory.count }.by(1)
        expect(UserHistory.last.custom_type).to eq("disable_rss_polling_feed")
      end
    end

    context "when enabling a disabled feed" do
      let(:enabled) { true }

      before { rss_feed.update!(enabled: false) }

      it { is_expected.to run_successfully }

      it "enables the feed" do
        expect { result }.to change { rss_feed.reload.enabled }.from(false).to(true)
      end

      it "logs the change as a staff action" do
        expect { result }.to change { UserHistory.count }.by(1)
        expect(UserHistory.last.custom_type).to eq("enable_rss_polling_feed")
      end
    end
  end
end
