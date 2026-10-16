# frozen_string_literal: true

RSpec.describe DsaStatementsController do
  describe "#classify" do
    fab!(:moderator)
    fab!(:reviewable, :reviewable_flagged_post)
    fab!(:statement) { Fabricate(:dsa_statement_of_record, reviewable_id: reviewable.id) }

    let(:params) do
      {
        community_rule: DsaStatementOfRecord.community_rules.first.fetch("id"),
        category: "STATEMENT_CATEGORY_ILLEGAL_OR_HARMFUL_SPEECH",
        statement_ids: [statement.id],
      }
    end

    before do
      SiteSetting.dsa_reporting_enabled = true
      SiteSetting.dsa_community_rules = [
        {
          ground: "Terms, section 3",
          explanation: "The content targets another person with insults.",
        },
      ].to_json
    end

    it "returns forbidden when a nonstaff user classifies a flagged post" do
      sign_in(Fabricate(:user))

      put("/review/#{reviewable.id}/dsa-classification.json", params:)

      expect(response).to have_http_status(:forbidden)
    end

    it "allows a full moderator to classify a flagged post they can review" do
      sign_in(moderator)

      put("/review/#{reviewable.id}/dsa-classification.json", params:)

      note = reviewable.reviewable_notes.last

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["dsa_classification"]).to eq("statement_ids" => [])
      expect(response.parsed_body["reviewable_notes"].sole).to include(
        "id" => note.id,
        "content" => note.content,
        "user" => include("id" => moderator.id),
      )
    end

    it "returns not found for an unknown reviewable" do
      sign_in(moderator)

      put("/review/0/dsa-classification.json", params:)

      expect(response).to have_http_status(:not_found)
    end

    it "returns a generic error for an unknown community rule" do
      sign_in(moderator)
      params[:community_rule] = "unknown"

      put("/review/#{reviewable.id}/dsa-classification.json", params:)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["errors"]).to include(I18n.t("dsa_statements.errors.failed"))
    end

    it "returns validation errors for an invalid category" do
      sign_in(moderator)
      params[:category] = "unknown"

      put("/review/#{reviewable.id}/dsa-classification.json", params:)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["errors"]).to include(a_string_matching(/Category/))
    end

    it "rejects a second classification of the same statement" do
      sign_in(moderator)
      statement.update!(status: :ready)

      put("/review/#{reviewable.id}/dsa-classification.json", params:)

      expect(response).to have_http_status(:conflict)
      expect(response.parsed_body["errors"]).to include(
        I18n.t("dsa_statements.errors.statements_changed"),
      )
    end
  end
end
