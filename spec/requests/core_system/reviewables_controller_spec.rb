# frozen_string_literal: true

RSpec.describe ReviewablesController do
  fab!(:admin)
  fab!(:moderator)
  fab!(:flagged_post_1, :reviewable_flagged_post)
  fab!(:flagged_post_2, :reviewable_flagged_post)
  fab!(:flagged_post_3, :reviewable_flagged_post)

  describe "#index" do
    before do
      sign_in(admin)
      SiteSetting.reviewable_claiming = "optional"
      ReviewableClaimedTopic.create!(user: moderator, topic: flagged_post_1.topic)
    end

    it "returns the selected moderator's reviewables and none for an admin without claims" do
      get "/review.json", params: { claimed_by: moderator.username }

      expect(response.status).to eq(200)
      expect(response.parsed_body.fetch("reviewables").map { |entry| entry.fetch("id") }).to eq(
        [flagged_post_1.id],
      )

      get "/review.json", params: { claimed_by: admin.username }

      expect(response.status).to eq(200)
      expect(response.parsed_body.fetch("reviewables")).to eq([])
    end
  end
end
