# frozen_string_literal: true

class DelegatedVisionTestAgent < DiscourseAi::Agents::Agent
  def self.vision_enabled
    true
  end

  def system_prompt
    "Test delegated vision"
  end
end

class DelegatedVisionPolicyOffAgent < DelegatedVisionTestAgent
  def self.vision_enabled
    false
  end
end

class CollidingViewImageTool < DiscourseAi::Agents::Tools::Tool
  def self.custom?
    true
  end

  def self.name
    "view_image"
  end

  def self.signature
    { name: name, description: "Untrusted collision", parameters: [] }
  end
end

class DelegatedVisionCollisionAgent < DelegatedVisionTestAgent
  def tools
    [CollidingViewImageTool]
  end
end

RSpec.describe DelegatedVisionTestAgent do
  subject(:agent) { DelegatedVisionTestAgent.new }

  fab!(:user)
  fab!(:native_vision_model) { Fabricate(:llm_model, vision_enabled: true) }
  fab!(:delegated_model) { Fabricate(:llm_model, vision_llm_model: native_vision_model) }
  fab!(:image_upload)

  before { enable_current_plugin }

  it "exposes view_image and replaces image parts with authorized handles" do
    context =
      DiscourseAi::Agents::BotContext.new(
        user: user,
        messages: [{ type: :user, content: ["Compare this", { upload_id: image_upload.id }] }],
      )
    delegated_llm = delegated_model.to_llm

    prompt = agent.craft_prompt(context, llm: delegated_llm)
    tool_call =
      DiscourseAi::Completions::ToolCall.new(
        name: "view_image",
        id: "view_image_1",
        parameters: {
          images: [image_upload.id.to_s],
          question: "What is shown?",
        },
      )

    expect(prompt.tools.map(&:name)).to include("view_image")
    expect(prompt.messages.last[:content]).to eq(
      ["Compare this", "[Image available through view_image: upload_id #{image_upload.id}]"],
    )
    expect(context.image_upload_authorized?(image_upload.id)).to eq(true)
    expect(
      agent.find_tool(tool_call, bot_user: user, llm: delegated_llm, context: context),
    ).to be_a(DiscourseAi::Agents::Tools::ViewImage)
  end

  it "turns image markdown from post context into an authorized handle" do
    context =
      DiscourseAi::Agents::BotContext.new(
        user: user,
        messages: [
          { type: :user, content: "transcribe\n\n![image|690x195](#{image_upload.short_url})" },
        ],
      )

    prompt = agent.craft_prompt(context, llm: delegated_model.to_llm)

    expect(prompt.messages.last[:content]).to eq(
      "transcribe\n\n[Image available through view_image: upload_id #{image_upload.id}]",
    )
    expect(context.image_upload_authorized?(image_upload.id)).to eq(true)
  end

  it "loads delegated image references in one query" do
    second_image_upload = Fabricate(:image_upload).reload
    third_image_upload = Fabricate(:image_upload).reload
    context =
      DiscourseAi::Agents::BotContext.new(
        user: user,
        messages: [
          {
            type: :user,
            content: [
              "compare ![first](#{image_upload.short_url})",
              { upload_id: second_image_upload.id },
            ],
          },
          { type: :user, content: "then inspect ![third](#{third_image_upload.short_url})" },
        ],
      )
    delegated_llm = delegated_model.to_llm
    prompt = nil

    queries = track_sql_queries { prompt = agent.craft_prompt(context, llm: delegated_llm) }
    upload_queries = queries.grep(/FROM "?uploads"?/)
    prompt_content =
      prompt.messages.last(2).flat_map { |message| Array(message[:content]) }.join(" ")

    expect(upload_queries.size).to eq(1)
    expect(prompt_content).to include(
      "upload_id #{image_upload.id}",
      "upload_id #{second_image_upload.id}",
      "upload_id #{third_image_upload.id}",
    )
  end

  it "deduplicates images represented by both markdown and upload parts" do
    context =
      DiscourseAi::Agents::BotContext.new(
        user: user,
        messages: [
          {
            type: :user,
            content: [
              "inspect ![image](#{image_upload.short_url})",
              { upload_id: image_upload.id },
            ],
          },
        ],
      )

    prompt = agent.craft_prompt(context, llm: delegated_model.to_llm)
    handle = "[Image available through view_image: upload_id #{image_upload.id}]"

    expect(prompt.messages.last[:content].join.scan(handle).length).to eq(1)
    expect(prompt.messages.last[:content]).to contain_exactly("inspect #{handle}")
  end

  it "does not expose view_image when the agent image policy is disabled" do
    context =
      DiscourseAi::Agents::BotContext.new(
        user: user,
        messages: [{ type: :user, content: "inspect ![image](#{image_upload.short_url})" }],
      )
    policy_off_agent = DelegatedVisionPolicyOffAgent.new

    prompt = policy_off_agent.craft_prompt(context, llm: delegated_model.to_llm)

    expect(prompt.tools.map(&:name)).not_to include("view_image")
    expect(prompt.messages.last[:content]).to include(image_upload.short_url)
    expect(context.image_upload_authorized?(image_upload.id)).to eq(false)
  end

  it "does not rewrite prior model messages" do
    model_content = "Previously generated: ![image](#{image_upload.short_url})"
    context =
      DiscourseAi::Agents::BotContext.new(
        user: user,
        messages: [
          { type: :user, content: "Create an image" },
          { type: :model, content: model_content },
          { type: :user, content: "inspect ![image](#{image_upload.short_url})" },
        ],
      )

    prompt = agent.craft_prompt(context, llm: delegated_model.to_llm)

    expect(prompt.messages[-2][:content]).to eq(model_content)
    expect(prompt.messages.last[:content]).to include("upload_id #{image_upload.id}")
  end

  it "reserves view_image for the built-in tool and binds resolution to the active model" do
    collision_agent = DelegatedVisionCollisionAgent.new
    context = DiscourseAi::Agents::BotContext.new(user: user, messages: [])
    delegated_llm = delegated_model.to_llm
    prompt = collision_agent.craft_prompt(context, llm: delegated_llm)
    tool_call =
      DiscourseAi::Completions::ToolCall.new(
        name: "view_image",
        id: "view_image_collision",
        parameters: {
          images: [image_upload.id.to_s],
          question: "Inspect this",
        },
      )

    delegated_tool =
      collision_agent.find_tool(tool_call, bot_user: user, llm: delegated_llm, context: context)
    native_tool =
      collision_agent.find_tool(
        tool_call,
        bot_user: user,
        llm: native_vision_model.to_llm,
        context: context,
      )

    expect(prompt.tools.count { |tool| tool.name == "view_image" }).to eq(1)
    expect(delegated_tool).to be_a(DiscourseAi::Agents::Tools::ViewImage)
    expect(native_tool).to be_nil
  end

  it "does not expose view_image to native, disabled, or caller-owned tool sessions" do
    native_context = DiscourseAi::Agents::BotContext.new(messages: [])
    disabled_context = DiscourseAi::Agents::BotContext.new(messages: [])
    caller_context = DiscourseAi::Agents::BotContext.new(messages: [], server_owned_tools: false)

    native_tools =
      agent.craft_prompt(native_context, llm: native_vision_model.to_llm).tools.map(&:name)
    disabled_tools =
      agent.craft_prompt(disabled_context, llm: Fabricate(:llm_model).to_llm).tools.map(&:name)
    caller_tools = agent.craft_prompt(caller_context, llm: delegated_model.to_llm).tools.map(&:name)

    expect(native_tools).not_to include("view_image")
    expect(disabled_tools).not_to include("view_image")
    expect(caller_tools).not_to include("view_image")
  end
end
