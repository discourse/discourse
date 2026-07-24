# frozen_string_literal: true

return unless defined?(::DiscourseSolved)

RSpec.describe DiscourseAi::Agents::Tools::MarkAsSolved do
  fab!(:llm_model)
  let(:bot_user) { DiscourseAi::AiBot::EntryPoint.find_user_from_model(llm_model.name) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy(llm_model) }
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic: topic) }
  fab!(:reply, :post) { Fabricate(:post, topic: topic) }
  fab!(:reply2, :post) { Fabricate(:post, topic: topic) }

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
    SiteSetting.solved_enabled = true
    SiteSetting.allow_solved_on_all_topics = true
  end

  def tool(params = nil, **kwargs)
    params ||= kwargs
    described_class.new(params, bot_user: bot_user, llm: llm, context: context)
  end

  let(:context) { DiscourseAi::Agents::BotContext.new }

  it "marks a post as the accepted solution" do
    result = tool(post_id: reply.id, solved: true, reason: "This answers the question").invoke

    expect(result[:status]).to eq("success")
    expect(topic.reload.solved).to be_present
    expect(topic.topic_answers[0].post).to eq(reply)
  end

  it "unmarks existing solution when accepting another one" do
    result = tool(post_id: reply.id, solved: true, reason: "This answers the question").invoke
    expect(result[:status]).to eq("success")
    expect(topic.reload.solved).to be_present
    expect(topic.topic_answers.length).to eq(1)
    expect(topic.topic_answers[0].post).to eq(reply)

    result = tool(post_id: reply2.id, solved: true, reason: "This answers the question").invoke
    expect(result[:status]).to eq("success")
    expect(topic.reload.solved).to be_present
    expect(topic.topic_answers.length).to eq(1)
    expect(topic.topic_answers[0].post).to eq(reply2)
  end

  it "unmarks a post as the accepted solution" do
    DiscourseSolved::AcceptAnswer.call!(
      params: {
        post_id: reply.id,
      },
      guardian: Guardian.new(Discourse.system_user),
    )

    result = tool(post_id: reply.id, solved: false, reason: "Not the right answer").invoke

    expect(result[:status]).to eq("success")
    expect(topic.reload.solved).to be_nil
  end

  it "returns an error when reason is blank" do
    result = tool(post_id: reply.id, solved: true, reason: " ").invoke

    expect(result[:status]).to eq("error")
  end

  it "respects context user permissions via guardian" do
    return unless defined?(::DiscourseSolved)

    regular_user = Fabricate(:user, trust_level: TrustLevel[0])
    ctx = DiscourseAi::Agents::BotContext.new(user: regular_user)
    t =
      described_class.new(
        { post_id: reply.id, solved: true, reason: "test" },
        bot_user: bot_user,
        llm: llm,
        context: ctx,
      )
    result = t.invoke

    expect(result[:status]).to eq("error")
  end

  describe "with multiple solutions enabled" do
    before { SiteSetting.solved_allow_multiple_solutions = true }

    it "can accept/unaccept multiple solutions" do
      result = tool(post_id: reply.id, solved: true, reason: "This answers the question").invoke
      expect(result[:status]).to eq("success")
      expect(topic.reload.solved).to be_present
      expect(topic.topic_answers.length).to eq(1)
      expect(topic.topic_answers[0].post).to eq(reply)

      result = tool(post_id: reply2.id, solved: true, reason: "This answers the question").invoke
      expect(result[:status]).to eq("success")
      expect(topic.reload.solved).to be_present
      expect(topic.topic_answers.length).to eq(2)
      expect(topic.topic_answers[0].post).to eq(reply)
      expect(topic.topic_answers[1].post).to eq(reply2)

      result = tool(post_id: reply.id, solved: false, reason: "Not the right answer").invoke
      expect(result[:status]).to eq("success")
      expect(topic.reload.solved).to be_present
      expect(topic.topic_answers.length).to eq(1)
      expect(topic.topic_answers[0].post).to eq(reply2)

      result = tool(post_id: reply2.id, solved: false, reason: "Not the right answer").invoke
      expect(result[:status]).to eq("success")
      expect(topic.reload.solved).to be_nil
    end
  end
end
