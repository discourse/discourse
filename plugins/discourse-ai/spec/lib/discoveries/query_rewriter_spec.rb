# frozen_string_literal: true

describe DiscourseAi::Discoveries::QueryRewriter do
  subject(:rewriter) { described_class.new(user:, ai_agent:, llm_model:) }

  fab!(:user)
  fab!(:llm_model)
  fab!(:ai_agent) do
    Fabricate(
      :ai_agent,
      system_prompt: "Prepare two search queries.",
      tools: [["Search", {}, true]],
      temperature: 0.2,
      top_p: 0.7,
    )
  end

  before { enable_current_plugin }

  it "uses the configured agent for one tool-free structured rewrite" do
    warning = nil
    feature_name = nil
    allow(Rails.logger).to receive(:warn) { |message| warning = message }
    allow(DiscourseAi::Agents::BotContext).to receive(:new).and_wrap_original do |original, **args|
      feature_name = args[:feature_name]
      original.call(**args)
    end

    result =
      DiscourseAi::Completions::Llm.with_prepared_responses(
        [
          {
            keyword_query: "delete admin bot user",
            semantic_query: "how to remove a bot account with administrator permissions",
          },
        ],
      ) do |_, _, prompts, prompt_options|
        response = rewriter.call("怎么删除具备管理员权限的幽灵机器人用户？")

        prompt = prompts.first
        expect(prompt.system_message_text).to eq(ai_agent.system_prompt)
        expect(prompt.tools).to be_empty
        expect(prompt_options.first).to include(temperature: 0.2, top_p: 0.7)
        expect(prompt_options.first[:response_format]).to include(
          type: "json_schema",
          json_schema:
            include(
              schema:
                include(
                  properties:
                    include(
                      keyword_query: include(type: "string"),
                      semantic_query: include(type: "string"),
                    ),
                ),
            ),
        )
        expect(JSON.parse(prompt.messages.last[:content])).to eq(
          "query" => "怎么删除具备管理员权限的幽灵机器人用户？",
          "forum_default_locale" => SiteSetting.default_locale,
        )

        response
      end

    expect(warning).to be_nil
    expect(result).to have_attributes(
      keyword_query: "delete admin bot user",
      semantic_query: "how to remove a bot account with administrator permissions",
    )
    expect(feature_name).to eq("discover")
  end

  it "falls back to the original query when the agent returns unusable values" do
    result =
      DiscourseAi::Completions::Llm.with_prepared_responses(
        [{ keyword_query: " ", semantic_query: "" }],
      ) { rewriter.call("topic previe") }

    expect(result).to have_attributes(keyword_query: "topic previe", semantic_query: "topic previe")
  end

  it "falls back to the original query when rewriting fails" do
    bot = instance_double(DiscourseAi::Agents::Bot)
    allow(DiscourseAi::Agents::Bot).to receive(:as).and_return(bot)
    allow(bot).to receive(:reply).and_raise(StandardError)
    allow(Rails.logger).to receive(:warn)

    result = rewriter.call("猫")

    expect(result).to have_attributes(keyword_query: "猫", semantic_query: "猫")
    expect(Rails.logger).to have_received(:warn).with(
      "Discourse AI Discoveries query rewrite failed: StandardError",
    )
  end
end
