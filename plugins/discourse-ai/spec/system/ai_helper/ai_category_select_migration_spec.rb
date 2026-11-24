# frozen_string_literal: true

RSpec.describe "Category suggestion selection authority" do
  with_select_controls(true)

  fab!(:user) { Fabricate(:admin, refresh_auto_groups: true) }
  fab!(:embedding_definition)
  fab!(:category)
  fab!(:other_category, :category)

  let(:composer) { PageObjects::Components::Composer.new }
  let(:chooser) { PageObjects::Components::UiKit::DSelect.at("#reply-control .category-chooser") }
  let(:cdp) { PageObjects::CDP.new }
  let(:toasts) { PageObjects::Components::Toasts.new }

  before do
    enable_current_plugin
    assign_fake_provider_to(:ai_default_llm_model)
    SiteSetting.ai_helper_enabled = true
    SiteSetting.ai_helper_enabled_features = "suggestions"
    SiteSetting.ai_embeddings_enabled = true
    SiteSetting.ai_embeddings_selected_model = embedding_definition.id
    stub_request(:post, embedding_definition.url).to_return(
      status: 200,
      body: JSON.dump([[0.0038493] * embedding_definition.dimensions]),
    )
    sign_in(user)
    visit "/new-topic"
    composer.fill_title("Growing tomatoes in a small garden")
    chooser.select_value(category.id)
  end

  def track_category_request_cancellation
    page.execute_script <<~JS
      const original = XMLHttpRequest.prototype.open;
      XMLHttpRequest.prototype.open = function (method, url, ...args) {
        if (String(url).includes('/discourse-ai/ai-helper/suggest_category')) {
          this.addEventListener('abort', () => {
            document.body.dataset.categorySuggestionAborted = 'true';
          });
        }
        return original.call(this, method, url, ...args);
      };
    JS
  end

  def start_pending_suggestion
    chooser.open
    page.driver.with_playwright_page do |playwright_page|
      playwright_page.locator("[role='option'][data-value='ai-category-suggest']").click
    end
  end

  it "cancels a pending request when a newer category is picked" do
    track_category_request_cancellation
    cdp.with_pending_requests("**/discourse-ai/ai-helper/suggest_category") do
      start_pending_suggestion
      expect(page).to have_css("#reply-control .category-chooser[aria-busy='true']")

      chooser.select_value(other_category.id)

      expect(chooser).to have_selected_name(other_category.name)
      expect(page).to have_css("body[data-category-suggestion-aborted='true']")
    end
  end

  it "announces an empty result as well as showing the existing toast" do
    DiscourseAi::AiHelper::SemanticCategorizer.any_instance.stubs(:categories).returns([])
    chooser.select_value("ai-category-suggest")

    message = I18n.t("js.discourse_ai.ai_helper.suggest_errors.no_suggestions")
    expect(page).to have_css("#a11y-announcements-polite", text: message, visible: :all)
    expect(toasts).to have_error(message)
    expect(chooser).to have_selected_name(category.name)
  end

  it "uses the existing error popup when the request fails" do
    page.driver.with_playwright_page do |playwright_page|
      pattern = "**/discourse-ai/ai-helper/suggest_category"
      playwright_page.route(
        pattern,
        ->(route, _request) do
          route.fulfill(status: 422, json: { errors: ["Category suggestion failed"] })
        end,
      )
      chooser.select_value("ai-category-suggest")

      expect(PageObjects::Components::Dialog.new).to have_content("Category suggestion failed")
      expect(chooser).to have_selected_name(category.name)
    ensure
      playwright_page.unroute(pattern)
    end
  end
end
