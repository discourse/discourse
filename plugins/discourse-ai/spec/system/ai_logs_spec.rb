# frozen_string_literal: true

RSpec.describe "AI logs admin page" do
  fab!(:admin)
  fab!(:llm_model)
  fab!(:log) do
    Fabricate(
      :ai_api_audit_log,
      llm_model:,
      language_model: llm_model.name,
      feature_name: "system-test",
      raw_request_payload: '{"prompt":"Inspect this request"}',
      raw_response_payload: '{"answer":"Inspectable response"}',
      request_tokens: 20,
      response_tokens: 10,
      response_status: 200,
      duration_msecs: 1_400,
      time_to_first_token_msecs: 320,
      estimated_cost: 0,
    )
  end

  let(:ai_logs_page) { PageObjects::Pages::AiLogs.new }

  before do
    enable_current_plugin
    sign_in(admin)
  end

  it "applies typed feature and ID filters" do
    ai_logs_page.visit

    select I18n.t("js.discourse_ai.logs.failed"), from: I18n.t("js.discourse_ai.logs.outcome")
    expect(ai_logs_page).to have_no_log(log)

    select I18n.t("js.discourse_ai.logs.all_outcomes"), from: I18n.t("js.discourse_ai.logs.outcome")
    expect(ai_logs_page).to have_log(log)

    find("input[placeholder='#{I18n.t("js.discourse_ai.logs.feature_placeholder")}']").fill_in(
      with: "missing-feature",
    )
    find("input[placeholder='#{I18n.t("js.discourse_ai.logs.feature_placeholder")}']").send_keys(
      :enter,
    )
    expect(ai_logs_page).to have_no_log(log)

    find("input[placeholder='#{I18n.t("js.discourse_ai.logs.id_placeholder")}']").fill_in(
      with: log.id,
    )
    find(".ai-logs__id-filter .btn", text: I18n.t("js.discourse_ai.logs.find")).click
    expect(ai_logs_page).to have_log(log)
  end

  it "keeps focus in the feature input while typing" do
    ai_logs_page.visit

    feature_input =
      find("input[placeholder='#{I18n.t("js.discourse_ai.logs.feature_placeholder")}']")
    feature_input.click
    "abc".each_char { |char| feature_input.send_keys(char) }

    expect(feature_input.value).to eq("abc")
    expect(page.evaluate_script("document.activeElement.placeholder")).to eq(
      I18n.t("js.discourse_ai.logs.feature_placeholder"),
    )
  end

  it "restores model and period filters from the URL" do
    other_model = Fabricate(:llm_model)
    other_log =
      Fabricate(
        :ai_api_audit_log,
        llm_model: other_model,
        language_model: other_model.name,
        created_at: 10.minutes.ago,
      )

    ai_logs_page.visit("model=#{other_model.id}&period=hour")

    expect(ai_logs_page).to have_log(other_log)
    expect(ai_logs_page).to have_no_log(log)
  end

  it "lets an admin inspect a raw log and open retention configuration" do
    ai_logs_page.visit

    expect(ai_logs_page).to have_log(log)

    ai_logs_page.open_log(log)
    expect(ai_logs_page).to have_payload("Inspect this request")
    expect(page).to have_css(".ai-log-detail-modal__metadata-duration", text: "1.4 s")
    expect(page).to have_css(".ai-log-detail-modal__metadata-first-token", text: "0.3 s")
    expect(page).to have_no_css(".ai-log-detail-modal__metadata-cost")
    expect(page).to have_current_path(/details=#{log.id}/, url: true)

    page.go_back
    expect(page).to have_no_css(".ai-log-detail-modal")
    expect(page).to have_current_path(%r{/ai-logs$}, url: true)

    page.go_forward
    expect(ai_logs_page).to have_payload("Inspect this request")
    find(".ai-log-detail-modal .modal-close").click
    ai_logs_page.open_retention
    expect(ai_logs_page).to have_retention_modal
    expect(page).to have_field(
      I18n.t("js.discourse_ai.logs.retention.detailed_title"),
      with: SiteSetting.ai_audit_logs_detailed_retention_days,
    )
    expect(page).to have_no_text(I18n.t("js.discourse_ai.logs.retention.destructive_warning"))

    fill_in I18n.t("js.discourse_ai.logs.retention.detailed_title"), with: 30
    fill_in I18n.t("js.discourse_ai.logs.retention.summary_title"), with: 180
    expect(page).to have_text(I18n.t("js.discourse_ai.logs.retention.destructive_warning"))

    fill_in I18n.t("js.discourse_ai.logs.retention.summary_title"), with: 10
    click_button I18n.t("js.discourse_ai.logs.retention.save")
    expect(page).to have_text(I18n.t("js.discourse_ai.logs.retention.invalid_order"))
  end
end
