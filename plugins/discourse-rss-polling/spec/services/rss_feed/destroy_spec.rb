# frozen_string_literal: true

RSpec.describe DiscourseRssPolling::RssFeed::Destroy do
  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:rss_feed)

    let(:params) { { id: rss_feed.id } }
    let(:dependencies) { { guardian: admin.guardian } }

    context "when the feed does not exist" do
      let(:params) { { id: -1 } }

      it { is_expected.to fail_to_find_a_model(:rss_feed) }
    end

    context "when the feed exists" do
      it { is_expected.to run_successfully }

      it "destroys the feed" do
        expect { result }.to change { DiscourseRssPolling::RssFeed.count }.by(-1)
        expect(DiscourseRssPolling::RssFeed.exists?(rss_feed.id)).to eq(false)
      end

      it "logs the deletion as a staff action" do
        expect { result }.to change { UserHistory.count }.by(1)
        expect(UserHistory.last).to have_attributes(
          custom_type: "destroy_rss_polling_feed",
          acting_user_id: admin.id,
        )
      end
    end
  end
end
