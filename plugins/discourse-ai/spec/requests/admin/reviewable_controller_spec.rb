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

  it "filters by the stable AI triage automation score context" do
    reviewable.add_score(
      Discourse.system_user,
      ReviewableScore.types[:needs_approval],
      context: DiscourseAi::Automation.triage_automation_context(42),
    )
    reviewable2.add_score(
      Discourse.system_user,
      ReviewableScore.types[:needs_approval],
      context: DiscourseAi::Automation.triage_automation_context(43),
    )
    sign_in(admin)

    get "/review.json", params: { additional_filters: { ai_triage_automation_id: 42 }.to_json }

    expect(response.status).to eq(200)
    expect(response.parsed_body["reviewables"].map { |item| item["id"] }).to contain_exactly(
      reviewable.id,
    )
  end

  it "rejects a malformed AI triage automation ID" do
    sign_in(admin)

    get "/review.json",
        params: {
          additional_filters: { ai_triage_automation_id: "1) OR TRUE--" }.to_json,
        }

    expect(response.status).to eq(400)
  end
end
