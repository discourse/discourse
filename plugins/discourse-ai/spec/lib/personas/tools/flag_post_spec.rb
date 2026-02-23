# frozen_string_literal: true

RSpec.describe DiscourseAi::Personas::Tools::FlagPost do
  fab!(:llm_model)
  let(:bot_user) { DiscourseAi::AiBot::EntryPoint.find_user_from_model(llm_model.name) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy(llm_model) }
  fab!(:post)

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
  end

  def tool(params = nil, persona_options: {}, **kwargs)
    params ||= kwargs
    described_class.new(
      params,
      bot_user: bot_user,
      llm: llm,
      context: context,
      persona_options: persona_options,
    )
  end

  let(:context) { DiscourseAi::Personas::BotContext.new(post: post) }

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
        persona_options: {
          flag_type: "review_hide",
        },
      ).invoke

    expect(result[:status]).to eq("flagged")
    expect(post.reload).to be_hidden
  end

  it "escapes llm response and automation name in automation flag reasons" do
    context =
      DiscourseAi::Personas::BotContext.new(
        post: post,
        feature_context: {
          automation_id: "123",
          automation_name: %(rule"><img src=x onerror=1>),
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
        persona_options: {
        },
      ).invoke

    expect(result[:status]).to eq("flagged")

    score_reason = ReviewablePost.last.reviewable_scores.first.reason
    expect(score_reason).to include("&lt;img src=x onerror=alert(1)&gt;")
    expect(score_reason).to include("rule&quot;&gt;&lt;img src=x onerror=1&gt;")
    expect(score_reason).not_to include("<img src=x onerror=alert(1)>")
    expect(score_reason).not_to include(%(rule"><img src=x onerror=1>))
  end
end
