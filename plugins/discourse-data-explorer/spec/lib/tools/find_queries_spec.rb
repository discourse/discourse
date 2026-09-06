# frozen_string_literal: true

describe DiscourseDataExplorer::Tools::FindQueries do
  fab!(:llm_model)
  fab!(:admin)
  fab!(:user)

  let(:bot_user) { DiscourseAi::AiBot::EntryPoint.find_user_from_model(llm_model.name) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy(llm_model) }

  before do
    SiteSetting.discourse_ai_enabled = true
    SiteSetting.data_explorer_enabled = true
    SiteSetting.ai_bot_enabled = true
  end

  def invoke_with(user:, search: "warehouse unicorn", limit: nil)
    parameters = { search: search }
    parameters[:limit] = limit if limit

    described_class.new(
      parameters,
      bot_user: bot_user,
      llm: llm,
      context: DiscourseAi::Agents::BotContext.new(user: user),
    ).invoke
  end

  it "returns matching visible queries with SQL for inspiration" do
    query =
      Fabricate(
        :query,
        name: "Warehouse Unicorn Activity",
        description: "Shows warehouse unicorn activity by month",
        sql: <<~SQL,
          -- [params]
          -- int :minimum_posts = 5

          SELECT COUNT(*) AS post_count
          FROM posts
          HAVING COUNT(*) >= :minimum_posts
        SQL
      )

    result = invoke_with(user: admin)

    expect(result[:query_count]).to eq(1)
    expect(result[:queries].first).to include(
      id: query.id,
      name: "Warehouse Unicorn Activity",
      description: "Shows warehouse unicorn activity by month",
      is_default: false,
    )
    expect(result[:queries].first[:sql]).to include("SELECT COUNT(*) AS post_count")
    expect(result[:queries].first[:params]).to contain_exactly(
      include(identifier: "minimum_posts", type: :int),
    )
    expect(result[:note]).to include("examples")
  end

  it "includes bundled default queries" do
    result = invoke_with(user: admin, search: "user participation")

    expect(result[:queries].map { |query| query[:id] }).to include(-8)
    expect(result[:queries].find { |query| query[:id] == -8 }).to include(is_default: true)
  end

  it "omits hidden saved queries" do
    Fabricate(
      :query,
      name: "Warehouse Unicorn Hidden",
      description: "Should not be visible",
      sql: "SELECT 1",
      hidden: true,
    )

    result = invoke_with(user: admin)

    expect(result[:queries]).to be_empty
  end

  it "blocks a non-admin caller" do
    result = invoke_with(user: user)

    expect(result[:status]).to eq("error")
    expect(result[:error]).to eq(I18n.t("discourse_data_explorer.errors.tool_not_allowed"))
  end
end
