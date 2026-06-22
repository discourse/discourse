# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::AiAgent::V1 do
  fab!(:llm_model) { Fabricate(:llm_model, display_name: "Workflow LLM") }
  fab!(:site_llm_model) { Fabricate(:llm_model, display_name: "Site LLM") }
  fab!(:agent) do
    Fabricate(:ai_agent, name: "Workflow agent", enabled: true, default_llm_id: llm_model.id)
  end

  let(:bot) { instance_double(DiscourseAi::Agents::Bot) }
  let(:bot_as_users) { [] }
  let(:bot_contexts) { [] }
  let(:bot_models) { [] }
  let(:prompts) { [] }

  before do
    SiteSetting.discourse_ai_enabled = true

    allow(DiscourseAi::Agents::Bot).to receive(:as) do |user, agent:, model:|
      bot_as_users << user
      bot_models << model
      bot
    end
    allow(bot).to receive(:reply) do |bot_context, &block|
      prompt = bot_context.messages.first[:content]

      bot_contexts << bot_context
      prompts << prompt
      block.call("Reply to #{prompt}", nil, nil)
    end
  end

  describe ".load_options_context" do
    fab!(:disabled_agent) { Fabricate(:ai_agent, name: "Disabled agent", enabled: false) }
    fab!(:matching_agent) do
      Fabricate(:ai_agent, name: "Alpha agent", enabled: true, default_llm_id: llm_model.id)
    end
    fab!(:other_agent) do
      Fabricate(:ai_agent, name: "Gamma agent", enabled: true, default_llm_id: llm_model.id)
    end

    def load_options(method_name: "agents", filter: nil, parameters: {})
      context =
        DiscourseWorkflows::LoadOptionsContext.new(
          method_name: method_name,
          filter: filter,
          parameters: parameters,
          node_class: described_class,
        )

      described_class.load_options_context(context)
    end

    it "returns enabled AI agents for the chooser and includes resolved LLM metadata" do
      option_ids = [agent.id, disabled_agent.id]
      options = load_options.select { |option| option_ids.include?(option[:id]) }

      expect(options).to contain_exactly(
        {
          id: agent.id,
          name: agent.name,
          default_llm_id: llm_model.id,
          force_default_llm: false,
          resolved_llm_id: llm_model.id,
          resolved_llm_name: llm_model.display_name,
        },
      )
    end

    it "includes the site default LLM in agent metadata when the agent has no default" do
      agent.update!(default_llm_id: nil)
      SiteSetting.stubs(:ai_default_llm_model).returns(site_llm_model.id)

      option = load_options.find { |agent_option| agent_option[:id] == agent.id }

      expect(option).to include(
        name: agent.name,
        default_llm_id: nil,
        resolved_llm_id: site_llm_model.id,
        resolved_llm_name: site_llm_model.display_name,
      )
    end

    it "filters AI agents by the filter term" do
      option_ids = [matching_agent.id, other_agent.id]
      options = load_options(filter: "alpha").select { |option| option_ids.include?(option[:id]) }

      expect(options.first[:id]).to eq(matching_agent.id)
    end

    it "returns LLM models for the override chooser" do
      override_model = Fabricate(:llm_model, display_name: "Override LLM")

      expect(load_options(method_name: "llm_models").pluck(:id)).to include(
        llm_model.id,
        site_llm_model.id,
        override_model.id,
      )
    end
  end

  it "declares an explicit runner actor control" do
    runner_schema = described_class.property_schema[:runner_username]

    expect(runner_schema).to include(type: :string, default: "system")
    expect(runner_schema[:ui]).to include(control: :actor)
  end

  it "runs the agent once per input item with item-specific parameters" do
    items =
      execute_node_output(
        configuration: {
          "agent_id" => agent.id,
          "prompt" => "={{ 'Prompt ' + $json.name }}",
        },
        input_items: [{ "json" => { "name" => "Ada" } }, { "json" => { "name" => "Grace" } }],
      ).first

    expect(prompts).to eq(["Prompt Ada", "Prompt Grace"])
    expect(items.map { |item| item["json"]["result"] }).to eq(
      ["Reply to Prompt Ada", "Reply to Prompt Grace"],
    )
    expect(items.map { |item| item["pairedItem"] }).to eq([{ "item" => 0 }, { "item" => 1 }])
    expect(bot).to have_received(:reply).twice
  end

  it "uses the system user as the default runner" do
    execute_node_output(configuration: { "agent_id" => agent.id, "prompt" => "Hello" })

    expect(bot_as_users).to eq([Discourse.system_user])
    expect(bot_contexts.last.user).to eq(Discourse.system_user)
    expect(bot_contexts.last.guardian.user).to eq(Discourse.system_user)
  end

  it "uses a specific configured runner for agent context and permissions" do
    runner = Fabricate(:user)

    execute_node_output(
      configuration: {
        "agent_id" => agent.id,
        "runner_username" => runner.username,
        "prompt" => "Hello",
      },
    )

    expect(bot_contexts.last.user).to eq(runner)
    expect(bot_contexts.last.guardian.user).to eq(runner)
  end

  it "supports anonymous as the configured runner" do
    execute_node_output(
      configuration: {
        "agent_id" => agent.id,
        "runner_username" => DiscourseWorkflows::AnonymousActor::USERNAME,
        "prompt" => "Hello",
      },
    )

    expect(bot_contexts.last.user).to be_a(DiscourseWorkflows::AnonymousActor)
    expect(bot_contexts.last.guardian).to be_anonymous
  end

  it "passes configured upload IDs to the agent prompt" do
    agent.update!(vision_enabled: true)
    upload = Fabricate(:image_upload)

    execute_node_output(
      configuration: {
        "agent_id" => agent.id,
        "prompt" => "Review the screenshot",
        "upload_ids" => "={{ $json.upload_ids }}",
      },
      input_items: [{ "json" => { "upload_ids" => [upload.id] } }],
    )

    expect(prompts).to eq([["Review the screenshot", { upload_id: upload.id }]])
  end

  it "filters image upload IDs when the agent does not have vision enabled" do
    agent.update!(vision_enabled: false)
    upload = Fabricate(:image_upload)

    execute_node_output(
      configuration: {
        "agent_id" => agent.id,
        "prompt" => "Review the screenshot",
        "upload_ids" => [upload.id],
      },
    )

    expect(prompts).to eq(["Review the screenshot"])
  end

  it "filters upload IDs the execution user cannot see" do
    agent.update!(vision_enabled: true)
    visible_upload = Fabricate(:image_upload)
    hidden_upload = Fabricate(:image_upload)
    owner = Fabricate(:user)
    recipient = Fabricate(:user)
    private_topic = Fabricate(:private_message_topic, user: owner, recipient: recipient)
    private_post = Fabricate(:post, topic: private_topic, user: owner)
    hidden_upload.update!(access_control_post_id: private_post.id)

    runner = Fabricate(:user)

    execute_node_output(
      configuration: {
        "agent_id" => agent.id,
        "runner_username" => runner.username,
        "prompt" => "Review the screenshot",
        "upload_ids" => [visible_upload.id, hidden_upload.id],
      },
    )

    expect(prompts).to eq([["Review the screenshot", { upload_id: visible_upload.id }]])
  end

  it "resolves runner expressions per item" do
    agent.update!(vision_enabled: true)
    owner = Fabricate(:user)
    runner = Fabricate(:user)
    private_topic = Fabricate(:private_message_topic, user: owner, recipient: runner)
    private_post = Fabricate(:post, topic: private_topic, user: owner)
    upload = Fabricate(:image_upload)
    upload.update!(access_control_post_id: private_post.id)

    execute_node_output(
      configuration: {
        "agent_id" => agent.id,
        "runner_username" => "={{ $json.runner_username }}",
        "prompt" => "Review the screenshot",
        "upload_ids" => [upload.id],
      },
      input_items: [{ "json" => { "runner_username" => runner.username } }],
    )

    expect(bot_contexts.last.user).to eq(runner)
    expect(prompts).to eq([["Review the screenshot", { upload_id: upload.id }]])
  end

  it "normalizes comma-separated and JSON upload ID values" do
    agent.update!(vision_enabled: true)
    first_upload = Fabricate(:image_upload)
    second_upload = Fabricate(:image_upload)

    execute_node_output(
      configuration: {
        "agent_id" => agent.id,
        "prompt" => "Review the uploads",
        "upload_ids" => "#{first_upload.id}, not-an-id, #{second_upload.id}",
      },
    )

    expect(prompts).to eq(
      [["Review the uploads", { upload_id: first_upload.id }, { upload_id: second_upload.id }]],
    )

    prompts.clear

    execute_node_output(
      configuration: {
        "agent_id" => agent.id,
        "prompt" => "Review the uploads",
        "upload_ids" =>
          "[#{first_upload.id}, {\"id\": #{second_upload.id}}, true, \"#{second_upload.id}\"]",
      },
    )

    expect(prompts).to eq(
      [["Review the uploads", { upload_id: first_upload.id }, { upload_id: second_upload.id }]],
    )
  end

  it "passes document upload IDs when the selected LLM supports their attachment type" do
    llm_model.update!(allowed_attachment_types: ["pdf"])
    SiteSetting.authorized_extensions += "|pdf"
    agent.update!(vision_enabled: false)
    upload = Fabricate(:upload, original_filename: "report.pdf", extension: "pdf")

    execute_node_output(
      configuration: {
        "agent_id" => agent.id,
        "prompt" => "Review the document",
        "upload_ids" => [upload.id],
      },
    )

    expect(prompts).to eq([["Review the document", { upload_id: upload.id }]])
  end

  it "uses an empty string when the optional prompt is blank" do
    items = execute_node_output(configuration: { "agent_id" => agent.id }).first

    expect(prompts).to eq([""])
    expect(items.first["json"]["result"]).to eq("Reply to ")
  end

  it "uses the selected LLM override when the agent does not force its default LLM" do
    override_model = Fabricate(:llm_model, display_name: "Override LLM")

    execute_node_output(
      configuration: {
        "agent_id" => agent.id,
        "llm_model_id" => override_model.id,
        "prompt" => "Hello",
      },
    )

    expect(bot_models).to contain_exactly(override_model)
  end

  it "ignores the selected LLM override when the agent forces its default LLM" do
    override_model = Fabricate(:llm_model, display_name: "Override LLM")
    agent.update!(force_default_llm: true)

    execute_node_output(
      configuration: {
        "agent_id" => agent.id,
        "llm_model_id" => override_model.id,
        "prompt" => "Hello",
      },
    )

    expect(bot_models).to contain_exactly(llm_model)
  end

  it "raises when the selected LLM override does not exist" do
    expect do
      execute_node_output(
        configuration: {
          "agent_id" => agent.id,
          "llm_model_id" => -999,
          "prompt" => "Hello",
        },
      )
    end.to raise_error(DiscourseWorkflows::NodeError, /LLM model with id -999 not found/)
  end

  it "raises when a forced agent has no valid default LLM" do
    agent.update_columns(force_default_llm: true, default_llm_id: -999)

    expect do
      execute_node_output(configuration: { "agent_id" => agent.id, "prompt" => "Hello" })
    end.to raise_error(
      DiscourseWorkflows::NodeError,
      /locked to its default LLM, but no valid default LLM is configured/,
    )
  end

  it "raises when no selected, agent, or site default LLM is configured" do
    agent.update!(default_llm_id: nil)
    SiteSetting.stubs(:ai_default_llm_model).returns(nil)

    expect do
      execute_node_output(configuration: { "agent_id" => agent.id, "prompt" => "Hello" })
    end.to raise_error(
      DiscourseWorkflows::NodeError,
      /No LLM is configured for agent '#{agent.name}'/,
    )
  end
end
