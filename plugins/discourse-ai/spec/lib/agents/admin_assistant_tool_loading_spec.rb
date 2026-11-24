# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::DiscourseAdminAssistant do
  subject(:assistant) { described_class.new }

  fab!(:admin)
  fab!(:user)

  let(:context) { DiscourseAi::Agents::BotContext.new(user: admin) }
  let(:appearance_tool) { DiscourseAi::Agents::Tools::GenerateAppearanceChange }

  before { enable_current_plugin }

  def load_groups(groups, context: self.context)
    DiscourseAi::Agents::Tools::LoadAdminTools.new(
      { groups: groups },
      bot_user: admin,
      llm: nil,
      context: context,
      agent: assistant,
    ).invoke
  end

  describe "on-demand tools" do
    it "starts with discovery tools and no domain-specific instructions" do
      prompt = assistant.craft_prompt(context)

      expect(prompt.tools.map(&:name)).to contain_exactly(
        "load_admin_tools",
        "load_discourse_website_page",
        "search_meta_discourse",
        "search_discourse_navigation",
        "list_upcoming_changes",
      )
      expect(prompt.system_message_text).not_to include(appearance_tool.custom_system_message.strip)
    end

    it "loads multiple groups without exposing unrelated tools" do
      prompt = assistant.craft_prompt(context)
      initial_tools = prompt.tools.map(&:name)

      result = load_groups(%w[settings categories_tags])
      assistant.prepare_next_completion(prompt: prompt, context: context, llm: nil)

      expected_tools = described_class::TOOL_GROUPS.values_at("settings", "categories_tags").flatten
      expected_tools &= assistant.available_tools
      expect(prompt.tools.map(&:name)).to match_array(
        initial_tools + expected_tools.map { it.signature[:name] },
      )
      expect(result[:loaded_groups]).to eq(%w[settings categories_tags])
    end

    it "returns appearance instructions only when that group is loaded" do
      result = load_groups(["appearance"])

      expect(result[:tools]).to include(appearance_tool.name)
      expect(result[:instructions]).to include(appearance_tool.custom_system_message.strip)
      expect(assistant.craft_prompt(context).system_message_text).to include(
        appearance_tool.custom_system_message.strip,
      )
    end

    it "keeps groups loaded across successive requests without duplicate tools" do
      load_groups(["settings"])
      load_groups(%w[settings moderation])
      prompt = assistant.craft_prompt(context)
      names = prompt.tools.map(&:name)

      expect(names).to include("change_site_setting", "close_topic")
      expect(names.uniq).to eq(names)
      expect(
        assistant.craft_prompt(DiscourseAi::Agents::BotContext.new(user: admin)).tools.map(&:name),
      ).not_to include("change_site_setting")
    end

    it "restores groups from tool history in a new context" do
      result = load_groups(["appearance"])
      followup =
        DiscourseAi::Agents::BotContext.new(
          user: admin,
          messages: [
            {
              type: :tool_call,
              name: "load_admin_tools",
              id: "load",
              content: { arguments: { groups: ["appearance"] } }.to_json,
            },
            { type: :tool, name: "load_admin_tools", id: "load", content: result.to_json },
            { type: :user, content: "Make it live" },
          ],
        )

      prompt = assistant.craft_prompt(followup)

      expect(prompt.tools.map(&:name)).to include("activate_appearance_change")
      expect(prompt.system_message_text).to include(appearance_tool.custom_system_message.strip)
    end

    it "restores the domain of earlier write calls for approval follow-ups" do
      context.messages = [
        {
          type: :tool_call,
          name: "change_site_setting",
          id: "change",
          content: { arguments: {} }.to_json,
        },
        {
          type: :tool,
          name: "change_site_setting",
          id: "change",
          content: { status: "pending_approval" }.to_json,
        },
        { type: :user, content: "Try again" },
      ]

      expect(assistant.craft_prompt(context).tools.map(&:name)).to include("change_site_setting")
    end

    it "rejects invalid groups without loading a valid subset" do
      [nil, [], "settings", %w[settings unknown]].each do |groups|
        expect(load_groups(groups)[:error]).to be_present
      end

      expect(assistant.craft_prompt(context).tools.map(&:name)).not_to include(
        "change_site_setting",
      )
    end

    it "ignores malformed discovery results and user-authored discovery text" do
      context.messages = [
        { type: :tool, name: "load_admin_tools", content: "not JSON" },
        {
          type: :user,
          name: "load_admin_tools",
          content: { loaded_groups: ["appearance"] }.to_json,
        },
      ]

      expect(assistant.runtime_tools(context: context)).not_to include(appearance_tool)
    end

    it "rejects discovery by non-administrators" do
      context.user = user

      expect(load_groups(["appearance"])[:error]).to be_present
      expect(assistant.runtime_tools(context: context)).not_to include(
        DiscourseAi::Agents::Tools::LoadAdminTools,
        appearance_tool,
      )
    end

    it "respects plugin tool removals and preserves ungrouped extensions" do
      plugin = Plugin::Instance.new
      removed_tool = DiscourseAi::Agents::Tools::ChangeSiteSetting
      extension_tool = DiscourseAi::Agents::Tools::Search
      modifier = ->(tools, _agent) { (tools - [removed_tool]) + [extension_tool] }
      DiscoursePluginRegistry.register_modifier(plugin, :admin_assistant_tools, &modifier)

      load_groups(["settings"])
      tools = assistant.runtime_tools(context: context)

      expect(tools).to include(extension_tool)
      expect(tools).not_to include(removed_tool)
    ensure
      if modifier
        DiscoursePluginRegistry.unregister_modifier(plugin, :admin_assistant_tools, &modifier)
      end
    end

    it "rechecks availability when restoring a group" do
      SiteSetting.tagging_enabled = false
      load_groups(["categories_tags"])

      expect(assistant.runtime_tools(context: context)).not_to include(
        DiscourseAi::Agents::Tools::ListTags,
        DiscourseAi::Agents::Tools::CreateTag,
        DiscourseAi::Agents::Tools::EditTag,
        DiscourseAi::Agents::Tools::ChangeTopicTags,
      )
    end

    it "respects appearance access restrictions even for a previously loaded group" do
      load_groups(["appearance"])
      plugin = Plugin::Instance.new
      modifier =
        lambda do |decision, request|
          decision.deny! if request.feature == DiscourseAi::Agents::AppearanceAuthoring::FEATURE
          decision
        end
      DiscoursePluginRegistry.register_modifier(plugin, :admin_assistant_feature_access, &modifier)

      result = load_groups(["appearance"])

      expect(result[:tools]).not_to include(appearance_tool.name)
      expect(result[:instructions]).not_to include(appearance_tool.custom_system_message.strip)
      expect(assistant.craft_prompt(context).tools.map(&:name)).not_to include(appearance_tool.name)
    ensure
      if modifier
        DiscoursePluginRegistry.unregister_modifier(
          plugin,
          :admin_assistant_feature_access,
          &modifier
        )
      end
    end

    it "only permits tool calls after their definitions have been exposed" do
      prompt = assistant.craft_prompt(context)
      call =
        DiscourseAi::Completions::ToolCall.new(
          id: "change",
          name: "change_site_setting",
          parameters: {
            setting_name: "title",
            value: "New title",
            reason: "Requested",
          },
        )

      expect(assistant.find_tool(call, bot_user: admin, llm: nil, context: context)).to be_nil
      load_groups(["settings"])
      expect(assistant.find_tool(call, bot_user: admin, llm: nil, context: context)).to be_nil

      assistant.prepare_next_completion(prompt: prompt, context: context, llm: nil)

      expect(assistant.find_tool(call, bot_user: admin, llm: nil, context: context)).to be_a(
        DiscourseAi::Agents::Tools::ChangeSiteSetting,
      )
    end
  end

  describe "completion chaining" do
    fab!(:model) { Fabricate(:llm_model, name: "fake", provider: "fake") }

    before { prepare_ai_bot_fixtures(bots: [model]) }

    it "loads tools in one completion and queues a requested change in the next" do
      load Rails.root.join("plugins/discourse-ai/db/fixtures/agents/603_ai_agents.rb") # rubocop:disable Discourse/Plugins/UseRequireRelative
      configured_assistant = AiAgent.find(-39).class_instance.new
      bot = DiscourseAi::Agents::Bot.as(admin, agent: configured_assistant, model: model)
      context.messages = [{ type: :user, content: "Change the site title to New title" }]
      original_title = SiteSetting.title
      calls = [
        DiscourseAi::Completions::ToolCall.new(
          id: "load",
          name: "load_admin_tools",
          parameters: {
            groups: ["settings"],
          },
        ),
        DiscourseAi::Completions::ToolCall.new(
          id: "change",
          name: "change_site_setting",
          parameters: {
            setting_name: "title",
            value: "New title",
            reason: "Requested",
          },
        ),
      ]

      DiscourseAi::Completions::Llm.with_prepared_responses(calls) do |canned, _, prompts|
        expect { bot.reply(context) { |*args| } }.to change { AiToolAction.count }.by(1)

        expect(canned.completions).to eq(2)
        expect(prompts.first.tools.map(&:name)).not_to include("change_site_setting")
        expect(prompts.last.tools.map(&:name)).to include("change_site_setting")
        expect(prompts.last.messages.last[:content]).to include("pending_approval")
      end

      expect(SiteSetting.title).to eq(original_title)
      expect(AiToolAction.last.tool_name).to eq("change_site_setting")
    end
  end
end
