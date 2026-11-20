# frozen_string_literal: true

RSpec.describe DiscourseRewind::Action::AiUsage do
  fab!(:user)

  before { SiteSetting.discourse_ai_enabled = true }

  describe ".call" do
    it "returns nothing when there is too little usage to show" do
      AiApiRequestStat.create!(
        user_id: user.id,
        bucket_date: random_datetime,
        provider_id: 1,
        request_tokens: 10,
        response_tokens: 10,
      )

      expect(call_report).to be_nil
    end
  end

  describe ".filter_for_viewer" do
    let(:report) do
      { data: { total_requests: 1, model_usage: [{ name: "secret-model", count: 1 }] } }
    end

    it "hides the models from other users" do
      filtered =
        described_class.filter_for_viewer(
          report,
          guardian: Fabricate(:user).guardian,
          for_user: user,
        )

      expect(filtered[:data]).to eq(total_requests: 1)
    end

    it "shows the models to the owner and admins" do
      [user, Fabricate(:admin)].each do |viewer|
        expect(
          described_class.filter_for_viewer(report, guardian: viewer.guardian, for_user: user),
        ).to eq(report)
      end
    end
  end
end
