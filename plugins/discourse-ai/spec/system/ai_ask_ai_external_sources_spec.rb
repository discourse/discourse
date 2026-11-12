# frozen_string_literal: true

describe "Ask AI external sources" do
  fab!(:user) { Fabricate(:admin, refresh_auto_groups: true) }
  fab!(:category) { Fabricate(:category, name: "Account help") }
  fab!(:topic) { Fabricate(:topic, category:, title: "Password resets and account recovery") }
  fab!(:post) { Fabricate(:post, topic:, raw: "Use the forgot password link to reset it.") }
  fab!(:help_center) { Fabricate(:ai_tool, name: "Help center", script: <<~JS) }
      function invoke(params) {
        return [{
          title: "Resetting a forgotten password",
          url: "https://help.example.com/password",
          blurb: "Step by step instructions for every sign in method.",
          content: "Click forgot password on the login screen and follow the emailed link.",
        }];
      }
    JS

  let(:discoveries_search) { PageObjects::Components::AiDiscoveriesSearch.new }

  before do
    enable_current_plugin
    Fabricate(:theme_site_setting_with_service, name: "enable_welcome_banner", value: true)
    assign_fake_provider_to(:ai_default_llm_model)

    SiteSetting.discourse_ai_enabled = true
    SiteSetting.ai_ask_ai_enabled = true
    SiteSetting.ai_ask_ai_allowed_groups = Group::AUTO_GROUPS[:admins].to_s
    SiteSetting.ai_ask_ai_external_sources = help_center.id.to_s
    SiteSetting.ai_ask_ai_related_count = 2
    # searches with the asked query, so the fake model only has to answer
    SiteSetting.ai_ask_ai_query_rewriter_agent = 0
    SearchIndexer.enable
    SearchIndexer.index(topic, force: true)

    # the forum's result ranks first on a tie, then the external one
    DiscourseAi::Completions::Endpoints::Fake.fake_content = {
      answerable: true,
      title: "Resetting your password",
      answer: "Use the forgot password link on the login screen.",
      source_refs: %w[source_1 source_2],
      follow_up: "",
    }.to_json

    sign_in(user)
  end

  after do
    DiscourseAi::Completions::Endpoints::Fake.fake_content = nil
    SearchIndexer.disable
  end

  # The client subscribes as it asks, and skips updates published before it
  # knows its position on the channel, so the reply waits for that.
  def run_reply_job
    try_until_success { expect(Jobs::StreamDiscoverReply.jobs).to be_present }
    try_until_success(timeout: 10) { expect(page.evaluate_script(<<~JS)).to eq(true) }
        MessageBus.callbacks.some(
          (callback) => callback.channel === "/discourse-ai/discoveries" && callback.last_id !== -1
        )
      JS

    # the wait above is not the queue delay the job guards against
    args = Jobs::StreamDiscoverReply.jobs.last["args"].first.except("queued_at", "current_site_id")
    Jobs::StreamDiscoverReply.new.execute(args.symbolize_keys)
  end

  it "lists the forum's and the external source's results together under the answer" do
    visit "/"
    discoveries_search.open.fill_query("password").submit
    run_reply_job

    expect(page).to have_css(
      ".ai-discobot-discoveries .cooked",
      text: "Use the forgot password link on the login screen.",
    )
    expect(discoveries_search).to have_forum_source(topic, category:)
    expect(discoveries_search).to have_external_source(
      title: "Resetting a forgotten password",
      url: "https://help.example.com/password",
      source_name: "Help center",
    )
    expect(page).to have_css(
      ".ai-discovery-source__excerpt",
      text: "Step by step instructions for every sign in method.",
    )
  end

  it "lists the forum's and the external source's results together in the combined search" do
    SiteSetting.enable_ai_combined_search = true

    visit "/"
    find("#welcome-banner-search-input").fill_in(with: "how do I reset my password")
    find("#welcome-banner-search-input").send_keys(:enter)
    run_reply_job

    within(".ai-search-answer__more") do
      expect(page).to have_css(
        ".ai-search-topic-row:not([target]) .ai-search-topic-row__category",
        text: category.name,
      )
      expect(page).to have_css(
        ".ai-search-topic-row[href='https://help.example.com/password'][target='_blank'] .ai-search-topic-row__source",
        text: "Help center",
      )
    end
  end
end
