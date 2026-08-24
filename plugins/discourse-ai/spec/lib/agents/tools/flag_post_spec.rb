# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::Tools::FlagPost do
  it "does not require separate approval before adding a post to the review queue" do
    expect(described_class.requires_approval?).to eq(false)
  end

  fab!(:llm_model)
  let(:bot_user) { DiscourseAi::AiBot::EntryPoint.find_user_from_model(llm_model.name) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy(llm_model) }
  fab!(:post)

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
  end

  def tool(params = nil, agent_options: {}, **kwargs)
    params ||= kwargs
    described_class.new(
      params,
      bot_user: bot_user,
      llm: llm,
      context: context,
      agent_options: agent_options,
    )
  end

  let(:context) { DiscourseAi::Agents::BotContext.new(post: post) }

  it "flags the post when flag_post is true" do
    result = nil

    expect { result = tool(flag_post: true, reason: "Clear spam").invoke }.to change {
      ReviewablePost.count
    }.by(1)

    expect(result[:status]).to eq("flagged")
    reviewable = ReviewablePost.find_by(target: post)
    score =
      ReviewableScore.find_by(
        reviewable: reviewable,
        user: Discourse.system_user,
        reviewable_score_type: ReviewableScore.types[:needs_approval],
      )
    expect(score.reason).to include("Clear spam")
    expect(score.context).to be_nil
  end

  it "skips when flag_post is false" do
    result = nil

    expect { result = tool(flag_post: false, reason: "Does not matter").invoke }.not_to change {
      ReviewablePost.count
    }

    expect(result[:status]).to eq("skipped")
  end

  it "skips when the post is already flagged" do
    reviewable = ReviewablePost.needs_review!(target: post, created_by: Discourse.system_user)
    reviewable.add_score(
      Discourse.system_user,
      ReviewableScore.types[:needs_approval],
      reason: "Existing flag",
      force_review: true,
    )

    result = nil

    expect { result = tool(flag_post: true, reason: "Duplicate flag").invoke }.not_to change {
      ReviewableScore.count
    }

    expect(result[:status]).to eq("skipped")
  end

  it "returns an error when reason is blank" do
    result = tool(flag_post: true, reason: " ").invoke

    expect(result[:status]).to eq("error")
  end

  it "applies the configured flag_type option" do
    result =
      tool(
        { flag_post: true, reason: "Needs review" },
        agent_options: {
          flag_type: "review_hide",
        },
      ).invoke

    expect(result[:status]).to eq("flagged")
    expect(post.reload).to be_hidden
  end

  it "sanitizes the llm response and renders the automation name literally" do
    automation_name = %(rule"><img src=x onerror=1>)
    context =
      DiscourseAi::Agents::BotContext.new(
        post:,
        feature_context: {
          automation_id: "123",
          automation_name:,
          llm_response: "<img src=x onerror=alert(1)>",
          base_path: Discourse.base_path,
        },
      )

    result =
      described_class.new(
        { flag_post: true, reason: "fallback reason" },
        bot_user: bot_user,
        llm: llm,
        context: context,
        agent_options: {
        },
      ).invoke

    expect(result[:status]).to eq("flagged")

    score = ReviewablePost.last.reviewable_scores.first
    serialized =
      ReviewableScoreSerializer.new(score, scope: Discourse.system_user.guardian, root: nil)

    expect(serialized.reason).to match_html(<<~HTML)
      <p>
        <b>
          Triggered by the
          <a href="/admin/plugins/automation/automation/123">#{CGI.escapeHTML(automation_name)}</a>
          rule.
        </b>
      </p>
      <p>Response from the model: <img src=""></p>
    HTML
    expect(score.context).to eq(DiscourseAi::Automation.triage_automation_context(123))
  end

  it "stores the automation context on spam scores while preserving their reason" do
    automation = Fabricate(:automation, name: "Agent spam triage", script: "llm_agent_triage")
    context =
      DiscourseAi::Agents::BotContext.new(
        post:,
        feature_context: {
          automation_id: automation.id,
          automation_name: automation.name,
        },
      )

    result =
      described_class.new(
        { flag_post: true, reason: "Spam links" },
        bot_user: bot_user,
        llm: llm,
        context: context,
        agent_options: {
          flag_type: "spam",
        },
      ).invoke

    score = ReviewableFlaggedPost.find_by(target: post).reviewable_scores.first

    expect(result[:status]).to eq("flagged")
    expect(score.context).to eq(DiscourseAi::Automation.triage_automation_context(automation.id))
    expect(score.reason).to include(automation.name)
  end
end
