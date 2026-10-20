# frozen_string_literal: true

RSpec.describe DiscourseDataExplorer::AdminAssistant::CreateQuery do
  fab!(:admin)
  fab!(:other_admin, :admin)
  fab!(:user)
  fab!(:ai_agent)

  let(:query) do
    {
      name: "Recent users",
      description: "Lists recent users",
      sql: "SELECT id AS user_id FROM users",
    }
  end
  let(:token) { DiscourseDataExplorer::AdminAssistant::QueryDraft.sign(query, user: admin) }
  let(:context) { DiscourseAi::Agents::BotContext.new(user: admin, messages: []) }
  let(:tool) do
    described_class.new({ draft_token: token }, bot_user: Discourse.system_user, llm: nil, context:)
  end

  before do
    SiteSetting.discourse_ai_enabled = true
    SiteSetting.data_explorer_enabled = true
    SiteSetting.data_explorer_ai_queries_enabled = true
    DiscourseDataExplorer::AdminAssistant::Capability.stubs(:status).returns(:available)
  end

  def build_reviewable(draft_token = token, requester_id: admin.id)
    action =
      AiToolAction.create!(
        tool_name: described_class.name,
        tool_parameters: {
          draft_token:,
          requester_id:,
        },
        ai_agent:,
        bot_user_id: Discourse.system_user.id,
      )
    ReviewableAiToolAction
      .needs_review!(
        target: action,
        created_by: Discourse.system_user,
        reviewable_by_moderator: true,
      )
      .tap do |reviewable|
        reviewable.add_score(
          Discourse.system_user,
          ReviewableScore.types[:needs_approval],
          force_review: true,
        )
      end
  end

  it "requires approval and shows the exact query without its token" do
    expect(described_class.mandatory_approval?).to eq(true)
    expect(tool.details).to include(query[:name], query[:description], query[:sql])
    expect(tool.details).not_to include(token)
    expect(tool.approval_parameters).to be_empty
    expect { tool.invoke }.not_to change { DiscourseDataExplorer::Query.count }
  end

  it "saves the approved draft unchanged with the approver as owner and returns its URL" do
    reviewable = build_reviewable

    expect { reviewable.perform(other_admin, :approve) }.to change {
      DiscourseDataExplorer::Query.count
    }.by(1)
    saved = DiscourseDataExplorer::Query.order(:id).last
    expect(saved).to have_attributes(query.merge(user_id: other_admin.id))
    expect(saved.query_groups).to be_empty
    expect(reviewable.payload&.dig("continuation", "tool_result")).to be_nil
  end

  it "binds approval to the signed requester and exact draft token" do
    wrong_requester = build_reviewable(requester_id: other_admin.id)
    wrong_token = build_reviewable("#{token}tampered")

    expect { wrong_requester.perform(other_admin, :approve) }.to raise_error(
      Discourse::InvalidAccess,
    )
    expect { wrong_token.perform(other_admin, :approve) }.to raise_error(Discourse::InvalidAccess)
    expect(DiscourseDataExplorer::Query.count).to eq(0)
  end

  it "rejects unauthorized and invalid drafts" do
    context.user = user
    expect(tool.validation_error[:status]).to eq("error")

    context.user = admin
    tool.parameters[:draft_token] = "#{token}tampered"
    expect(tool.validation_error[:status]).to eq("error")
  end

  it "rechecks public capability and requester authorization at approval time" do
    reviewable = build_reviewable
    DiscourseDataExplorer::AdminAssistant::Capability.stubs(:status).returns(:restricted)

    expect { reviewable.perform(other_admin, :approve) }.to raise_error(Discourse::InvalidAccess)
    expect(reviewable.reload).to be_pending

    DiscourseDataExplorer::AdminAssistant::Capability.stubs(:status).returns(:available)
    admin.update!(admin: false)
    expect { reviewable.perform(other_admin, :approve) }.to raise_error(Discourse::InvalidAccess)
    expect(DiscourseDataExplorer::Query.count).to eq(0)
  end

  it "prevents replay through another approval" do
    first = build_reviewable
    second = build_reviewable

    first.perform(admin, :approve)
    expect { second.perform(other_admin, :approve) }.to raise_error(Discourse::InvalidAccess)
    expect(DiscourseDataExplorer::Query.count).to eq(1)
  end

  it "releases the replay claim when the approval transaction rolls back" do
    reviewable = build_reviewable
    replay_context = DiscourseAi::Agents::BotContext.new(user: other_admin, messages: [])
    replay_context.reviewable_id = reviewable.id
    replay_tool =
      described_class.new(
        { draft_token: token, requester_id: admin.id },
        bot_user: Discourse.system_user,
        llm: nil,
        context: replay_context,
      )

    expect do
      DiscourseDataExplorer::Query.transaction(requires_new: true) do
        expect(replay_tool.invoke[:status]).to eq("success")
        raise ActiveRecord::Rollback
      end
    end.not_to change { DiscourseDataExplorer::Query.count }
    expect(
      DiscourseDataExplorer::AdminAssistant::QueryDraft.claim(token, reviewable_id: reviewable.id),
    ).to eq(true)
    DiscourseDataExplorer::AdminAssistant::QueryDraft.release(token, reviewable_id: reviewable.id)
  end

  it "resolves the tools by name but hides them at runtime when restricted" do
    DiscourseDataExplorer::AdminAssistant::Capability.stubs(:status).returns(:restricted)
    runtime_context = DiscourseAi::Agents::BotContext.new(user: admin, messages: [])

    expect(
      DiscourseAi::Agents::DiscourseAdminAssistant.new.runtime_tools(context: runtime_context),
    ).not_to include(described_class)
    expect(DiscourseAi::Agents::Agent.external_tool_by_name("CreateQuery")).to eq(described_class)
    expect(DiscourseAi::Agents::Agent.external_tool_by_name("GenerateQuery")).to eq(
      DiscourseDataExplorer::AdminAssistant::GenerateQuery,
    )
  end
end

RSpec.describe DiscourseDataExplorer::AdminAssistant::GenerateQuery do
  fab!(:admin)

  let(:context) { DiscourseAi::Agents::BotContext.new(user: admin, messages: []) }
  let(:tool) do
    described_class.new(
      { description: "Recent users" },
      bot_user: Discourse.system_user,
      llm: nil,
      context:,
    )
  end
  let(:query) do
    {
      name: "Recent users",
      description: "Lists recent users",
      sql: "SELECT id AS user_id FROM users",
    }
  end

  before { DiscourseDataExplorer::AdminAssistant::Capability.stubs(:status).returns(:available) }

  it "generates a bounded signed draft without saving a query" do
    DiscourseDataExplorer::QueryGeneration
      .expects(:call)
      .with(user: admin, ai_description: "Recent users")
      .returns(query)

    result = nil
    expect { result = tool.invoke }.not_to change { DiscourseDataExplorer::Query.count }
    expect(result[:status]).to eq("success")
    expect(DiscourseDataExplorer::AdminAssistant::QueryDraft.read(result[:draft_token])).to include(
      query.merge(user_id: admin.id),
    )
  end

  it "denies policy before query generation and rejects oversized requests" do
    DiscourseDataExplorer::AdminAssistant::Capability.stubs(:status).returns(:restricted)
    DiscourseDataExplorer::QueryGeneration.expects(:call).never
    expect(tool.invoke[:status]).to eq("error")

    DiscourseDataExplorer::AdminAssistant::Capability.stubs(:status).returns(:available)
    tool.parameters[:description] = "x" * (described_class::MAX_DESCRIPTION_LENGTH + 1)
    expect(tool.invoke[:status]).to eq("error")
  end
end
