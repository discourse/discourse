# frozen_string_literal: true

RSpec.describe "AI logs admin page" do
  fab!(:admin)
  fab!(:llm_model)
  fab!(:other_llm_model) { Fabricate(:llm_model, display_name: "Another model") }
  fab!(:log) do
    Fabricate(
      :ai_api_audit_log,
      llm_model:,
      language_model: llm_model.name,
      feature_name: "system-test",
      raw_request_payload: '{"prompt":"Inspect this request"}',
      raw_response_payload: <<~SSE,
        data: {"choices":[{"delta":{"reasoning":"Inspect before answering"}}]}

        data: {"choices":[{"delta":{"content":"Inspectable decoded response"}}]}

        data: [DONE]

      SSE
      request_tokens: 20,
      response_tokens: 10,
      response_status: 200,
      duration_msecs: 1_400,
      time_to_first_token_msecs: 320,
      estimated_cost: 0,
      feature_context: {
        source: "system test",
      },
    )
  end

  let(:ai_logs_page) { PageObjects::Pages::AiLogs.new }

  def expect_modal_body_to_own_scrolling
    overflow = page.evaluate_script(<<~JS)
        (() => {
          const modal = document.querySelector(".ai-log-detail-modal");
          const body = modal.querySelector(".d-modal__body");
          const payload = modal.querySelector(".ai-payload-viewer__content");

          return {
            modal: getComputedStyle(modal).overflowY,
            body: getComputedStyle(body).overflowY,
            payload: getComputedStyle(payload).overflowY,
          };
        })()
      JS

    expect(overflow).to eq("modal" => "hidden", "body" => "auto", "payload" => "visible")
    expect(page).to have_css(".ai-payload-viewer.--unbounded")
    expect(page).to have_css(".ai-payload-viewer__content:not([tabindex])")
  end

  def expect_top_copy(label)
    expect(page).to have_css(".ai-log-detail-modal__tabs .ai-log-detail-modal__copy", text: label)
    expect(page).to have_no_css(".ai-payload-viewer__copy")
    expect(page).to have_no_css(".ai-log-detail-modal input[type='hidden']", visible: :all)
  end

  before do
    enable_current_plugin
    sign_in(admin)
  end

  it "applies outcome, feature, and ID filters" do
    Fabricate(:ai_api_audit_log, feature_name: "other-feature")
    ai_logs_page.visit

    ai_logs_page.select_outcome(I18n.t("js.discourse_ai.logs.failed"))
    expect(ai_logs_page).to have_no_log(log)

    ai_logs_page.select_outcome(I18n.t("js.discourse_ai.logs.all_outcomes"))
    expect(ai_logs_page).to have_log(log)

    ai_logs_page.select_feature("other-feature")
    expect(ai_logs_page).to have_no_log(log)

    ai_logs_page.select_period(I18n.t("js.discourse_ai.logs.periods.day"))
    expect(page).to have_current_path(/period=day/, url: true)

    # an ID search narrows within the active filters instead of bypassing them
    ai_logs_page.search(log.id)
    expect(ai_logs_page).to have_no_log(log)
    expect(page).to have_current_path(/period=day/, url: true)

    ai_logs_page.select_feature(log.feature_name)
    expect(ai_logs_page).to have_log(log)
  end

  it "drops the model filter when a single model leaves nothing to choose" do
    other_llm_model.destroy!
    ai_logs_page.visit

    expect(ai_logs_page).to have_log(log)
    expect(page).to have_css(".d-filter-controls__dropdown--outcome")
    expect(page).to have_no_css(".d-filter-controls__dropdown--model")

    # a model carried in on the URL still needs somewhere to be cleared from
    ai_logs_page.visit("model=#{llm_model.id}")

    expect(ai_logs_page).to have_log(log)
    expect(ai_logs_page.filter_value(:model)).to eq(llm_model.id.to_s)
  end

  it "filters by a feature outside the initial page of logs" do
    Fabricate.times(50, :ai_api_audit_log, feature_name: "recent-feature")
    ai_logs_page.visit

    ai_logs_page.select_feature(log.feature_name)

    expect(ai_logs_page).to have_log(log)
  end

  it "searches logs by username and typed ID prefixes" do
    topic_log = Fabricate(:ai_api_audit_log, topic_id: 424_242)
    user_log = Fabricate(:ai_api_audit_log, user: admin)

    ai_logs_page.visit

    ai_logs_page.search(log.id)
    expect(ai_logs_page).to have_log(log)
    expect(ai_logs_page).to have_no_log(topic_log)

    ai_logs_page.search("topic:#{topic_log.topic_id}")
    expect(ai_logs_page).to have_log(topic_log)
    expect(ai_logs_page).to have_no_log(log)

    ai_logs_page.search(admin.username)
    expect(ai_logs_page).to have_log(user_log)
    expect(ai_logs_page).to have_no_log(log)

    combined_log = Fabricate(:ai_api_audit_log, user: admin, topic_id: 555_555)
    ai_logs_page.search("#{admin.username} topic:555555")
    expect(ai_logs_page).to have_log(combined_log)
    expect(ai_logs_page).to have_no_log(user_log)
    expect(ai_logs_page).to have_no_log(topic_log)
    expect(ai_logs_page).to have_no_log(log)
    expect(page).to have_current_path(/search=.*%20topic%3A555555/, url: true)

    # numeric token combined with a username token
    ai_logs_page.search("#{admin.username} 555555")
    expect(ai_logs_page).to have_log(combined_log)
    expect(ai_logs_page).to have_no_log(user_log)
    expect(ai_logs_page).to have_no_log(topic_log)
    expect(ai_logs_page).to have_no_log(log)
  end

  it "suggests and inserts a user picked from an @-prefixed search" do
    user_log = Fabricate(:ai_api_audit_log, user: admin)

    ai_logs_page.visit

    search_input = find("input[placeholder='#{I18n.t("js.discourse_ai.logs.search_placeholder")}']")
    search_input.click
    "@#{admin.username}".each_char { |char| search_input.send_keys(char) }

    within(".autocomplete.ac-user") { find(".username", text: admin.username).click }

    expect(page).to have_current_path(/search=%40#{Regexp.escape(admin.username)}/, url: true)
    expect(page.evaluate_script("document.activeElement.value")).to eq("@#{admin.username} ")
    expect(ai_logs_page).to have_log(user_log)
    expect(ai_logs_page).to have_no_log(log)
  end

  it "closes the user picker once a space ends the @username" do
    ai_logs_page.visit

    search_input = find("input[placeholder='#{I18n.t("js.discourse_ai.logs.search_placeholder")}']")
    search_input.click
    "@#{admin.username}".each_char { |char| search_input.send_keys(char) }
    expect(page).to have_css(".autocomplete.ac-user .username")

    search_input.send_keys(" ")
    expect(page).to have_no_css(".autocomplete.ac-user")

    # the mention context is gone, so the next search token must not reopen it
    search_input.send_keys("topic:")
    expect(page).to have_no_css(".autocomplete.ac-user")
  end

  it "keeps focus in the search box while typing and searching live" do
    ai_logs_page.visit

    search_input = find("input[placeholder='#{I18n.t("js.discourse_ai.logs.search_placeholder")}']")
    search_input.click
    "123".each_char { |character| search_input.send_keys(character) }

    expect(search_input.value).to eq("123")
    expect(page.evaluate_script("document.activeElement.placeholder")).to eq(
      I18n.t("js.discourse_ai.logs.search_placeholder"),
    )

    # the debounced search fires and the URL updates; focus must stay in the box
    expect(page).to have_current_path(/search=123/, url: true)
    expect(page.evaluate_script("document.activeElement.placeholder")).to eq(
      I18n.t("js.discourse_ai.logs.search_placeholder"),
    )
    expect(page.evaluate_script("document.activeElement.value")).to eq("123")
  end

  it "remembers whether the filter drawer is collapsed across reloads" do
    ai_logs_page.visit
    expect(ai_logs_page).to have_log(log)
    expect(ai_logs_page).to have_expanded_filter_dropdowns

    find(".d-filter-controls__toggle-filters").click
    expect(page).to have_no_css(".ai-logs .d-filter-controls__dropdown")

    page.refresh
    expect(page).to have_css(".ai-logs .d-filter-controls__toggle-filters")
    expect(page).to have_no_css(".ai-logs .d-filter-controls__dropdown")

    find(".d-filter-controls__toggle-filters").click
    expect(page).to have_css(".ai-logs .d-filter-controls__dropdown", count: 2)
  end

  it "flags active filters hiding behind a collapsed drawer" do
    ai_logs_page.visit
    unless ai_logs_page.has_expanded_filter_dropdowns?
      find(".d-filter-controls__toggle-filters").click
    end

    ai_logs_page.select_model(llm_model.display_name)
    expect(page).to have_css(".ai-logs__filters--drawer-active")
    expect(ai_logs_page).to have_no_tinted_filter_toggle

    find(".d-filter-controls__toggle-filters").click
    expect(page).to have_no_css(".ai-logs .d-filter-controls__dropdown")
    expect(ai_logs_page).to have_tinted_filter_toggle

    find(".d-filter-controls__toggle-filters").click
    expect(page).to have_css(".ai-logs .d-filter-controls__dropdown", count: 2)
    expect(ai_logs_page).to have_no_tinted_filter_toggle
  end

  it "restores model and period filters from the URL" do
    other_model = Fabricate(:llm_model)
    other_log =
      Fabricate(
        :ai_api_audit_log,
        llm_model: other_model,
        language_model: other_model.name,
        feature_name: "url-feature",
        created_at: 10.minutes.ago,
      )

    ai_logs_page.visit("model=#{other_model.id}&period=hour&feature=url-feature")

    expect(ai_logs_page).to have_log(other_log)
    expect(ai_logs_page).to have_no_log(log)
    expect(ai_logs_page.feature_filter_value).to eq("url-feature")
  end

  it "filters by a seeded model from selection and a shareable URL" do
    seeded_model = Fabricate(:seeded_model, id: -1)
    seeded_log =
      Fabricate(:ai_api_audit_log, llm_model: seeded_model, language_model: seeded_model.name)

    ai_logs_page.visit
    ai_logs_page.select_model(seeded_model.display_name)

    expect(ai_logs_page).to have_log(seeded_log)
    expect(ai_logs_page).to have_no_log(log)
    expect(page).to have_current_path(/model=-1/, url: true)

    ai_logs_page.visit("model=-1")

    expect(ai_logs_page.filter_value(:model)).to eq("-1")
    expect(ai_logs_page).to have_log(seeded_log)
    expect(ai_logs_page).to have_no_log(log)
  end

  it "clears shared and specialized filters" do
    ai_logs_page.visit

    ai_logs_page.select_model(llm_model.display_name)
    ai_logs_page.select_period(I18n.t("js.discourse_ai.logs.periods.day"))
    expect(page).to have_current_path(/model=#{llm_model.id}/, url: true)
    expect(page).to have_current_path(/period=day/, url: true)

    ai_logs_page.clear_filters
    expect(page).to have_current_path(%r{/ai-logs$}, url: true)
    expect(page).to have_css(".d-filter-controls__input:focus")
    expect(ai_logs_page).to have_log(log)

    ai_logs_page.select_period(I18n.t("js.discourse_ai.logs.periods.day"))
    ai_logs_page.select_model(llm_model.display_name)
    ai_logs_page.search(log.id)
    ai_logs_page.clear_filters
    expect(page).to have_current_path(%r{/ai-logs$}, url: true)
    expect(page).to have_css(".d-filter-controls__input:focus")
    expect(ai_logs_page).to have_log(log)
  end

  it "lets an admin inspect a raw log and open retention configuration" do
    ai_logs_page.visit
    expect(ai_logs_page).to have_log(log)
    expect(page).to have_css(".d-filter-controls__input")
    expect(page).to have_css(".d-filter-controls__toggle-filters")
    expect(page).to have_css(".ai-logs__feature-filter.combo-box")
    expect(page).to have_no_css(".d-filter-controls__reset")
    expect(page).to have_css(".ai-logs__filters")
    expect(ai_logs_page).to have_expanded_filter_dropdowns
    expect(page).to have_no_css(".ai-logs__retention")
    expect(page).to have_button(I18n.t("js.discourse_ai.logs.retention.configure"))
    expect(page).to have_button(I18n.t("js.discourse_ai.logs.refresh"))
    expect(page).to have_css(
      ".ai-logs__duration-heading",
      text: I18n.t("js.discourse_ai.logs.duration"),
    )
    expect(page).to have_css(
      ".ai-logs__tokens-heading",
      text: I18n.t("js.discourse_ai.logs.tokens_direction"),
    )

    ai_logs_page.open_log(log)
    expect(ai_logs_page).to have_payload("Inspect this request")
    expect_modal_body_to_own_scrolling
    expect_top_copy(I18n.t("js.discourse_ai.logs.detail.copy_request"))
    expect(page).to have_css(".ai-log-detail-modal__metadata-duration", text: "1.4 s")
    expect(page).to have_css(".ai-log-detail-modal__metadata-first-token", text: "0.3 s")
    expect(page).to have_no_css(".ai-log-detail-modal__metadata-cost")
    expect(page).to have_current_path(/details=#{log.id}/, url: true)

    find(
      ".ai-log-detail-modal__tabs .btn",
      text: I18n.t("js.discourse_ai.logs.detail.response"),
    ).click
    expect(page).to have_css(".ai-decoded-transcript__thinking", text: "Inspect before answering")
    expect(page).to have_css(
      ".ai-decoded-transcript__section.--response",
      text: "Inspectable decoded response",
    )
    expect(page).to have_css(
      ".ai-log-detail-modal__tabs .ai-log-detail-modal__response-toggle",
      text: I18n.t("js.discourse_ai.view_raw"),
    )
    expect_top_copy(I18n.t("js.discourse_ai.logs.detail.copy_response"))

    find(".ai-log-detail-modal__response-toggle").click
    expect(ai_logs_page).to have_payload("data:")
    expect_modal_body_to_own_scrolling
    expect_top_copy(I18n.t("js.discourse_ai.logs.detail.copy_raw_response"))
    expect(page).to have_css(
      ".ai-log-detail-modal__response-toggle",
      text: I18n.t("js.discourse_ai.view_decoded"),
    )

    find(".ai-log-detail-modal__response-toggle").click
    expect(page).to have_css(
      ".ai-decoded-transcript__section.--response",
      text: "Inspectable decoded response",
    )

    find(
      ".ai-log-detail-modal__tabs .btn",
      text: I18n.t("js.discourse_ai.logs.detail.context"),
    ).click
    expect(ai_logs_page).to have_payload("system test")
    expect_modal_body_to_own_scrolling
    expect_top_copy(I18n.t("js.discourse_ai.logs.detail.copy_context"))

    page.go_back
    expect(page).to have_no_css(".ai-log-detail-modal")
    expect(page).to have_current_path(%r{/ai-logs$}, url: true)

    page.go_forward
    expect(ai_logs_page).to have_payload("Inspect this request")
    find(".ai-log-detail-modal .modal-close").click
    expect(page).to have_current_path(%r{/ai-logs$}, url: true)
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
