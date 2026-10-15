# frozen_string_literal: true

describe ReviewablesController do
  fab!(:admin)
  fab!(:post)
  fab!(:reviewable) do
    Fabricate(:reviewable_flagged_post, target: post, target_created_by: post.user)
  end

  let(:rule) { { ground: "Be respectful", explanation: "Personal attacks are not allowed." } }
  let(:classification) do
    {
      community_rule: DsaStatementOfRecord.community_rules.first.fetch("id"),
      category: "STATEMENT_CATEGORY_OTHER_VIOLATION_TC",
    }
  end

  before do
    SiteSetting.dsa_reporting_enabled = true
    SiteSetting.dsa_community_rules = [rule].to_json
    sign_in(admin)
  end

  describe "#perform" do
    it "classifies the new statement using the configured rule and records a note" do
      put "/review/#{reviewable.id}/perform/delete_and_agree.json",
          params: {
            version: reviewable.version,
            dsa_classification: classification,
          }

      expect(response).to have_http_status(:ok)
      expect(post.reload).to be_trashed
      statement = reviewable.dsa_statement_of_records.sole
      expect(statement).to be_ready
      expect(statement.classified_by_id).to eq(admin.id)
      expect(statement.payload).to include(
        "incompatible_content_ground" => rule[:ground],
        "incompatible_content_explanation" => rule[:explanation],
        "category" => classification[:category],
      )
      expect(reviewable.reviewable_notes.sole.content).to include(rule[:ground])
    end

    it "rejects malformed classification, outdated rules and invalid categories before moderation" do
      [
        "invalid",
        [classification],
        classification.merge(community_rule: "outdated-rule"),
        classification.merge(category: "unknown-category"),
      ].each do |invalid_classification|
        put "/review/#{reviewable.id}/perform/delete_and_agree.json",
            params: {
              version: reviewable.version,
              dsa_classification: invalid_classification,
            }

        expect(response).to have_http_status(:bad_request)
        expect(reviewable.reload).to be_pending
        expect(post.reload).not_to be_trashed
        expect(reviewable.dsa_statement_of_records).to be_empty
      end
    end

    it "preserves optional classification for existing clients" do
      put "/review/#{reviewable.id}/perform/delete_and_agree.json",
          params: {
            version: reviewable.version,
          }

      expect(response).to have_http_status(:ok)
      expect(post.reload).to be_trashed
      expect(reviewable.dsa_statement_of_records.sole).to be_pending
    end

    it "rejects classification when reporting has been disabled" do
      SiteSetting.dsa_reporting_enabled = false

      put "/review/#{reviewable.id}/perform/delete_and_agree.json",
          params: {
            version: reviewable.version,
            dsa_classification: classification,
          }

      expect(response).to have_http_status(:forbidden)
      expect(reviewable.reload).to be_pending
      expect(post.reload).not_to be_trashed
    end

    it "keeps classification restricted to staff even when a category moderator can review" do
      category_moderator = Fabricate(:user)
      group = Fabricate(:group)
      group.add(category_moderator)
      Fabricate(:category_moderation_group, group: group, category: post.topic.category)
      SiteSetting.enable_category_group_moderation = true
      sign_in(category_moderator)

      put "/review/#{reviewable.id}/perform/delete_and_agree.json",
          params: {
            version: reviewable.version,
            dsa_classification: classification,
          }

      expect(response).to have_http_status(:forbidden)
      expect(reviewable.reload).to be_pending
      expect(post.reload).not_to be_trashed
    end
  end
end
