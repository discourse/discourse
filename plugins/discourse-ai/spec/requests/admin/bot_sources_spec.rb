# frozen_string_literal: true

RSpec.describe Admin::UsersController do
  fab!(:admin)
  fab!(:moderator)
  fab!(:bot) { Fabricate(:user, id: -101, username: "source_bot", email: "source_bot@example.com") }
  fab!(:other_bot) { Fabricate(:user, id: -102) }
  fab!(:unattributed_bot) { Fabricate(:user, id: -103) }
  fab!(:agent) { Fabricate(:ai_agent, user: bot) }

  before do
    enable_current_plugin
    sign_in(admin)
  end

  def listed_user(user)
    response.parsed_body.find { |entry| entry["id"] == user.id }
  end

  it "links all associated agents and models, including disabled agents" do
    disabled_agent = Fabricate(:ai_agent, user: bot, enabled: false)
    model = Fabricate(:llm_model)
    model.update_column(:user_id, bot.id)

    get "/admin/users/list/bots.json"

    expect(response.status).to eq(200)
    expect(listed_user(bot)["sources"]).to eq(
      [
        {
          "label" => agent.name,
          "url" => "/admin/plugins/discourse-ai/ai-agents/#{agent.id}/edit",
        },
        {
          "label" => disabled_agent.name,
          "url" => "/admin/plugins/discourse-ai/ai-agents/#{disabled_agent.id}/edit",
        },
        {
          "label" => model.display_name,
          "url" => "/admin/plugins/discourse-ai/ai-llms/#{model.id}/edit",
        },
      ],
    )
    expect(listed_user(unattributed_bot)["sources"]).to eq([])
  end

  it "retains historical attribution without a configuration link or duplicate source" do
    [bot, other_bot].each do |user|
      Fabricate(
        :user_custom_field,
        user:,
        name: DiscourseAi::AiBot::HISTORICAL_AI_USER_CUSTOM_FIELD,
        value: "true",
      )
    end

    get "/admin/users/list/bots.json"

    expect(listed_user(other_bot)["sources"]).to eq(
      [{ "label" => I18n.t("discourse_ai.ai_bot.sources.historical") }],
    )
    expect(listed_user(bot)["sources"].size).to eq(1)
    expect(listed_user(bot)["sources"].first["url"]).to end_with("/#{agent.id}/edit")
  end

  it "omits configuration metadata for moderators" do
    sign_in(moderator)

    get "/admin/users/list/bots.json"

    expect(response.status).to eq(200)
    expect(listed_user(bot)).not_to have_key("sources")
  end

  it "omits configuration metadata for moderators while the plugin is disabled" do
    SiteSetting.discourse_ai_enabled = false
    sign_in(moderator)

    get "/admin/users/list/bots.json"

    expect(response.status).to eq(200)
    expect(listed_user(bot)).not_to have_key("sources")
    expect(listed_user(bot)).not_to have_key("bot_inactive")
  end

  it "keeps sources unlinked and noted when the plugin is disabled" do
    SiteSetting.discourse_ai_enabled = false

    get "/admin/users/list/bots.json"

    expect(response.status).to eq(200)
    expect(listed_user(bot)["sources"]).to eq(
      [{ "label" => agent.name, "note" => I18n.t("discourse_ai.ai_bot.sources.plugin_disabled") }],
    )
  end

  it "marks AI bots inactive only while the plugin is disabled" do
    get "/admin/users/list/bots.json"
    expect(listed_user(bot)).not_to have_key("bot_inactive")

    SiteSetting.discourse_ai_enabled = false
    get "/admin/users/list/bots.json"

    expect(listed_user(bot)["bot_inactive"]).to eq(true)
    expect(listed_user(unattributed_bot)["bot_inactive"]).to eq(false)
  end

  it "links the spam detection bot to its settings" do
    SiteSetting.ai_spam_detection_user_id = other_bot.id

    get "/admin/users/list/bots.json"

    expect(response.status).to eq(200)
    expect(listed_user(other_bot)["sources"]).to eq(
      [
        {
          "label" => I18n.t("discourse_ai.ai_bot.sources.spam_detection"),
          "url" => "/admin/plugins/discourse-ai/ai-spam",
        },
      ],
    )
  end

  it "does not enrich other users lists" do
    get "/admin/users/list/new.json"

    expect(response.status).to eq(200)
    expect(listed_user(bot)).not_to have_key("sources")
  end

  it "respects subfolder installations" do
    set_subfolder "/forum"

    get "/admin/users/list/bots.json"

    expect(listed_user(bot)["sources"].first["url"]).to eq(
      "/forum/admin/plugins/discourse-ai/ai-agents/#{agent.id}/edit",
    )
  end

  it "loads source associations once for only the returned page" do
    Fabricate(:ai_agent, user: other_bot)

    queries =
      track_sql_queries { get "/admin/users/list/bots.json", params: { filter: bot.username } }
    source_queries =
      queries.select { |sql| sql.match?(/FROM "(?:ai_agents|llm_models|user_custom_fields)"/) }

    expect(listed_user(bot)["sources"].size).to eq(1)
    expect(response.parsed_body.map { |entry| entry["id"] }).to eq([bot.id])
    expect(source_queries.grep(/FROM "ai_agents"/).size).to eq(1)
    expect(source_queries.grep(/FROM "llm_models"/).size).to eq(1)
    expect(source_queries.grep(/FROM "user_custom_fields"/).size).to eq(1)

    queries = track_sql_queries { get "/admin/users/list/bots.json" }
    expect(listed_user(other_bot)["sources"].size).to eq(1)
    expect(queries.grep(/FROM "ai_agents"/).size).to eq(1)
    expect(queries.grep(/FROM "llm_models"/).size).to eq(1)
    expect(queries.grep(/FROM "user_custom_fields"/).size).to eq(1)
  end
end
