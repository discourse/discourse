# frozen_string_literal: true
RSpec.describe DsaStatementsController do
  fab!(:admin)
  fab!(:moderator)
  fab!(:member) { Fabricate(:user, trust_level: TrustLevel[2], refresh_auto_groups: true) }
  fab!(:flagged_post, :post)

  before { SiteSetting.dsa_reporting_enabled = true }

  describe "#classify" do
    it "requires queue access and protects a classified decision from replacement" do
      reviewable = PostActionCreator.inappropriate(member, flagged_post).reviewable
      reviewable.perform(admin, :delete_and_agree)
      statement = DsaStatementOfReason.find_by!(reviewable_id: reviewable.id)
      params = {
        decision_key: statement.decision_key,
        community_rule: "spam",
        category: "STATEMENT_CATEGORY_OTHER_VIOLATION_TC",
      }
      sign_in(member)
      post "/review/#{reviewable.id}/dsa-classification.json", params: params
      expect(response.status).to eq(403)
      expect(statement.reload.classified_at).to be_nil
      sign_in(moderator)
      UserDestroyer.new(admin).destroy(member)
      post "/review/#{reviewable.id}/dsa-classification.json",
           params: params.merge(community_rule: "unknown")
      expect(response.status).to eq(422)
      post "/review/#{reviewable.id}/dsa-classification.json", params: params
      expect(response.status).to eq(200)
      expect(statement.reload.community_rule).to eq("spam")
      expect(statement.classified_by_id).to eq(moderator.id)
      post "/review/#{reviewable.id}/dsa-classification.json",
           params: params.merge(community_rule: "private_information")
      expect(response.status).to eq(409)
      expect(statement.reload.community_rule).to eq("spam")
      expect(reviewable.reviewable_notes.count).to eq(1)
    end
  end

  describe "#retry_submission" do
    it "allows only administrators to retry a failed submission and retains its payload and identity" do
      statement = Fabricate(:dsa_statement_of_reason, status: :failed, error_code: "authentication")
      original = statement.payload
      sign_in(moderator)
      post "/review/#{statement.reviewable_id}/dsa-retry.json",
           params: {
             decision_key: statement.decision_key,
           }
      expect(response.status).to eq(403)
      sign_in(admin)

      post "/review/#{statement.reviewable_id}/dsa-retry.json",
           params: {
             decision_key: statement.decision_key,
           }

      expect(response.status).to eq(204)
      expect(statement.reload).to be_pending
      expect(statement.payload).to eq(original)
    end
  end

  describe "moderation edits" do
    it "records a queue edit when saved and rejects a forged association to another post" do
      reviewable = PostActionCreator.inappropriate(member, flagged_post).reviewable
      sign_in(admin)
      put "/posts/#{flagged_post.id}.json",
          params: {
            post: {
              raw: "A revised contribution after removing the personal attack.",
              reviewable_id: reviewable.id,
            },
          }
      expect(response.status).to eq(200)
      statement = DsaStatementOfReason.find_by!(reviewable_id: reviewable.id)
      expect(statement.payload["decision_visibility"]).to eq(
        ["DECISION_VISIBILITY_CONTENT_REMOVED"],
      )
      expect(reviewable.reload).to be_pending
      other_post = Fabricate(:post)

      put "/posts/#{other_post.id}.json",
          params: {
            post: {
              raw: "Trying to associate an unrelated edit.",
              reviewable_id: reviewable.id,
            },
          }

      expect(response.status).to eq(403)
      expect(other_post.reload.raw).not_to eq("Trying to associate an unrelated edit.")
      expect(DsaStatementOfReason.where(reviewable_id: reviewable.id).count).to eq(1)
    end
  end
end
