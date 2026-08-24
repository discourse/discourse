# frozen_string_literal: true

RSpec.describe ReviewablesController do
  fab!(:post1, :post)
  fab!(:post2, :post)
  fab!(:admin)
  fab!(:llm_model)

  fab!(:reviewable) do
    Reviewable.create!(
      target: post1,
      topic: post2.topic,
      type: ReviewablePost,
      created_by: admin,
      status: Reviewable.statuses[:pending],
    )
  end

  fab!(:reviewable2) do
    Reviewable.create!(
      target: post2,
      topic: post2.topic,
      type: ReviewablePost,
      created_by: admin,
      status: Reviewable.statuses[:pending],
    )
  end

  fab!(:ai_spam_log_missed) do
    AiSpamLog.create!(is_spam: false, post_id: post1.id, llm_model_id: llm_model.id)
  end

  before { enable_current_plugin }

  # we amend the behavior with a custom filter so we need to confirm it works
  it "properly applies custom filter" do
    sign_in(admin)

    get '/review.json?additional_filters={"ai_spam_false_negative":true}'
    expect(response.status).to eq(200)

    json = JSON.parse(response.body)
    expect(json["reviewables"].length).to eq(1)

    get "/review.json"
    expect(response.status).to eq(200)
    json = JSON.parse(response.body)
    expect(json["reviewables"].length).to eq(2)
  end

  describe "AI triage filters" do
    fab!(:automation) { Fabricate(:automation, name: "Politics check", script: "llm_triage") }
    fab!(:agent_automation) do
      Fabricate(:automation, name: "Sensitive content check", script: "llm_agent_triage")
    end

    before do
      reviewable.add_score(
        Discourse.system_user,
        ReviewableScore.types[:needs_approval],
        reason: "llm_triage",
        context: DiscourseAi::Automation.triage_automation_score_context(automation.id),
        force_review: true,
      )
    end

    it "adds AI triage to Type and automation names to Reason" do
      sign_in(admin)

      get "/review.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body.dig("meta", "reviewable_types")).to include("discourse_ai:triage")
      expect(response.parsed_body.dig("meta", "score_types")).to include(
        { "id" => "ai_triage_automation:#{automation.id}", "name" => automation.name },
        { "id" => "ai_triage_automation:#{agent_automation.id}", "name" => agent_automation.name },
      )
    end

    it "filters by AI triage Type and automation Reason" do
      sign_in(admin)

      get "/review.json?type=discourse_ai:triage"
      expect(response.status).to eq(200)
      ids = response.parsed_body["reviewables"].map { |json| json["id"] }
      expect(ids).to contain_exactly(reviewable.id)

      get "/review.json?type=discourse_ai:triage&score_type=ai_triage_automation:#{automation.id}"
      expect(response.status).to eq(200)
      ids = response.parsed_body["reviewables"].map { |json| json["id"] }
      expect(ids).to contain_exactly(reviewable.id)

      get "/review.json?score_type=ai_triage_automation:#{automation.id + 1}"
      expect(response.status).to eq(200)
      expect(response.parsed_body["reviewables"]).to be_empty
    end

    it "ignores malformed filter values instead of failing" do
      sign_in(admin)

      ["true", "[1]", "{\"x\":1}", "\"1 OR 1=1 --\"", "0", "1.9", "\"junk\""].each do |malformed|
        get "/review.json?additional_filters={\"ai_triage_automation_id\":#{CGI.escape(malformed)}}"
        expect(response.status).to eq(200)
        expect(response.parsed_body["reviewables"].length).to eq(2)
      end
    end
  end
end
