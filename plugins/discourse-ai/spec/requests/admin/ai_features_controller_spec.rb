# frozen_string_literal: true

RSpec.describe DiscourseAi::Admin::AiFeaturesController do
  let(:controller) { described_class.new }

  fab!(:admin)
  fab!(:group)
  fab!(:llm_model)
  fab!(:summarizer_agent, :ai_agent)
  fab!(:alternate_summarizer_agent, :ai_agent)

  before do
    enable_current_plugin
    sign_in(admin)
    assign_fake_provider_to(:ai_default_llm_model)
    SiteSetting.ai_bot_enabled = true
  end

  describe "#index" do
    it "lists all features backed by agents" do
      get "/admin/plugins/discourse-ai/ai-features.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["ai_features"].count).to eq(
        DiscourseAi::Configuration::Module.all.count(&:visible?),
      )
    end

    it "exposes the site settings that toggle modules and features" do
      SiteSetting.ai_summary_gists_enabled = true

      get "/admin/plugins/discourse-ai/ai-features.json"

      modules = response.parsed_body["ai_features"].index_by { |m| m["module_name"] }
      summarization = modules["summarization"]
      features = summarization["features"].index_by { |f| f["name"] }

      expect(modules["bot"]["enabled_setting"]).to eq(
        "name" => "ai_bot_enabled",
        "value" => true,
        "can_enable" => true,
      )
      expect(summarization["enabled_setting"]).to eq(
        "name" => "ai_summarization_enabled",
        "value" => false,
        "can_enable" => true,
      )
      expect(features["gists"]["enabled_setting"]).to eq(
        "name" => "ai_summary_gists_enabled",
        "value" => true,
        "can_enable" => true,
      )
      expect(features["topic_summaries"]["enabled_setting"]).to be_nil
      expect(modules["search"]["enabled_setting"]).to be_nil
    end

    it "reports when a setting cannot be enabled until it is configured" do
      get "/admin/plugins/discourse-ai/ai-features.json"

      spam = response.parsed_body["ai_features"].find { |m| m["module_name"] == "spam" }

      expect(spam["enabled_setting"]).to eq(
        "name" => "ai_spam_detection_enabled",
        "value" => false,
        "can_enable" => false,
      )
    end

    it "lists the decision models that work alongside agent backed features" do
      locale_model = Fabricate(:decision_model)
      intent_model = Fabricate(:decision_model)
      SiteSetting.ai_translation_locale_detector_decision_model = locale_model.id
      SiteSetting.ai_ask_ai_search_intent_decision_model = intent_model.id

      get "/admin/plugins/discourse-ai/ai-features.json"

      features =
        response.parsed_body["ai_features"]
          .flat_map { |m| m["features"] }
          .index_by { |f| f["name"] }

      expect(features["locale_detector"]["decision_model"]).to eq(
        "id" => locale_model.id,
        "display_name" => locale_model.display_name,
      )
      expect(features["locale_detector"]["agents"]).to be_present
      expect(features["ask_ai"]["decision_model"]).to eq(
        "id" => intent_model.id,
        "display_name" => intent_model.display_name,
      )
      expect(features["post_raw_translator"]).not_to have_key("decision_model")
    end

    describe "discord" do
      def discord_module
        get "/admin/plugins/discourse-ai/ai-features.json"
        response.parsed_body["ai_features"].find { |m| m["module_name"] == "discord" }
      end

      it "lists what is missing before Discord can reach the forum" do
        SiteSetting.ai_discord_search_enabled = true

        discord = discord_module

        expect(discord["module_enabled"]).to eq(false)
        expect(discord["status"]).to eq(
          "state" => "setup",
          "note_key" => "missing",
          "missing" => %w[app_id public_key allowed_servers],
        )
        expect(discord["enabled_setting"]).to include("value" => true)
      end

      it "cannot be enabled until it is configured" do
        expect(discord_module["enabled_setting"]).to include(
          "value" => false,
          "can_enable" => false,
        )
      end

      context "when configured" do
        before do
          SiteSetting.ai_discord_app_id = "123"
          SiteSetting.ai_discord_app_public_key = "abc"
          SiteSetting.ai_discord_allowed_guilds = "456"
          SiteSetting.ai_discord_search_enabled = true
        end

        it "uses forum search without an AI model in search mode" do
          discord = discord_module

          expect(discord).to include("module_enabled" => true, "status" => nil)
          expect(discord["features"].first).to include(
            "agentless" => true,
            "agentless_note" => "forum_search",
          )
        end

        it "needs an agent with a bot user in agent mode" do
          agent = Fabricate(:ai_agent)
          agent.ensure_user!
          SiteSetting.ai_discord_search_agent = agent.id
          SiteSetting.ai_discord_search_mode = "agent"

          expect(discord_module["status"]).to be_nil

          agent.update_columns(user_id: nil)
          discord = discord_module

          expect(discord["status"]).to include("missing" => ["agent"])
          expect(discord["features"].first).not_to have_key("agentless")
        end
      end
    end

    describe "embeddings" do
      def embeddings_module
        get "/admin/plugins/discourse-ai/ai-features.json"
        response.parsed_body["ai_features"].find { |m| m["module_name"] == "embeddings" }
      end

      it "needs an embedding model before anything else" do
        EmbeddingDefinition.delete_all

        expect(embeddings_module["status"]).to eq(
          "state" => "setup",
          "note_key" => "no_embedding_model",
        )
      end

      it "needs a model selected once one exists" do
        Fabricate(:embedding_definition)
        SiteSetting.ai_embeddings_selected_model = ""

        expect(embeddings_module["status"]).to eq(
          "state" => "setup",
          "note_key" => "no_embedding_model_selected",
        )
      end

      it "requires setup when the selected model was removed" do
        Fabricate(:embedding_definition)
        removed_model = Fabricate(:embedding_definition)
        SiteSetting.ai_embeddings_selected_model = removed_model.id
        removed_model.delete

        expect(embeddings_module["status"]).to eq(
          "state" => "setup",
          "note_key" => "no_embedding_model_selected",
        )
      end

      it "lists what embeddings power, each with its own switch" do
        embedding = Fabricate(:embedding_definition)
        SiteSetting.ai_embeddings_selected_model = embedding.id
        SiteSetting.ai_embeddings_enabled = true
        SiteSetting.ai_embeddings_semantic_related_topics_enabled = true

        embeddings = embeddings_module
        features = embeddings["features"].index_by { |f| f["name"] }

        expect(embeddings).to include(
          "module_enabled" => true,
          "status" => nil,
          "model_names" => [embedding.display_name],
        )
        expect(features.keys).to eq(%w[related_topics semantic_search quick_search hyde])
        expect(features["related_topics"]).to include(
          "agentless" => true,
          "enabled_setting" => {
            "name" => "ai_embeddings_semantic_related_topics_enabled",
            "value" => true,
            "can_enable" => true,
          },
        )
        expect(features["hyde"]).not_to have_key("agentless")
        expect(features["hyde"]["enabled_setting"]).to include(
          "name" => "ai_embeddings_semantic_search_use_hyde",
        )
      end
    end

    describe "AI helper access" do
      def helper_features
        get "/admin/plugins/discourse-ai/ai-features.json"
        response.parsed_body["ai_features"].find { |m| m["module_name"] == "ai_helper" }[
          "features"
        ].index_by { |f| f["name"] }
      end

      it "treats a tool no group can use as off" do
        AiAgent.find(SiteSetting.ai_helper_explain_agent.to_i).update!(allowed_group_ids: [])

        features = helper_features

        expect(features["explain"]).to include("enabled" => false, "access_by_agent_groups" => true)
        expect(features["proofread"]).to include("enabled" => true)
        expect(features["chat_thread_titles"]).not_to have_key("access_by_agent_groups")
      end

      it "lists the image tools the post illustrator loads automatically" do
        image_tool =
          Fabricate(
            :ai_tool,
            parameters: [{ name: "prompt", type: "string", description: "Prompt" }],
            script: "function invoke() { upload.create(); chain.setCustomRaw(); }",
          )

        expect(helper_features["post_illustrator"]["automatic_image_tools"]).to eq(
          [{ "id" => image_tool.id, "name" => image_tool.name }],
        )
      end

      it "needs setup for the post illustrator without an image generation tool" do
        expect(helper_features["post_illustrator"]).to include(
          "enabled" => false,
          "needs_setup" => "no_image_generation_tool",
        )
      end

      it "lists the other features that share a tool's agent" do
        SiteSetting.ai_helper_translator_agent = SiteSetting.ai_helper_explain_agent

        features = helper_features

        expect(features["explain"]["shared_with"]).to contain_exactly(
          { "module_name" => "ai_helper", "name" => "translator" },
        )
        expect(features["proofread"]["shared_with"]).to eq([])
      end
    end

    describe "chatbot agents" do
      fab!(:chatbot_agent) do
        Fabricate(
          :ai_agent,
          name: "Chatty",
          allow_personal_messages: true,
          allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
          default_llm_id: llm_model.id,
        )
      end
      fab!(:quiet_agent) do
        Fabricate(
          :ai_agent,
          name: "Quiet",
          allow_personal_messages: false,
          allow_topic_mentions: false,
          allow_chat_channel_mentions: false,
          allow_chat_direct_messages: false,
        )
      end

      before { chatbot_agent.ensure_user! }

      def bot_module
        get "/admin/plugins/discourse-ai/ai-features.json"
        response.parsed_body["ai_features"].find { |m| m["module_name"] == "bot" }
      end

      it "lists the agents that can be chatbots with where people reach them" do
        agents = bot_module["features"].first["chatbot_agents"].index_by { |a| a["name"] }

        expect(agents["Chatty"]).to include(
          "chatbot" => true,
          "personal_messages" => true,
          "topic_mentions" => false,
          "allowed_groups" => [
            { "id" => Group::AUTO_GROUPS[:trust_level_0], "name" => "trust_level_0" },
          ],
          "llm" => {
            "id" => llm_model.id,
            "name" => llm_model.display_name,
          },
        )
        expect(agents["Quiet"]).to include("chatbot" => false)
      end

      it "only counts agents people can talk to, which need a bot user" do
        headless = Fabricate(:ai_agent, allow_personal_messages: true)
        headless.update_columns(user_id: nil)

        bot = bot_module
        agent_ids = bot["features"].first["agents"].map { |a| a["id"] }

        expect(agent_ids).to include(chatbot_agent.id)
        expect(agent_ids).not_to include(headless.id, quiet_agent.id)
        expect(bot["status"]).to include(
          "state" => "on",
          "label_key" => "on_with_chatbot_agents",
          "count" => DiscourseAi::Configuration::Feature.lookup_bot_agent_ids.size,
        )
      end
    end

    describe "translation status" do
      def translation_module
        get "/admin/plugins/discourse-ai/ai-features.json"
        response.parsed_body["ai_features"].find { |m| m["module_name"] == "translation" }
      end

      it "needs setup until languages are selected, even when the setting is on" do
        SiteSetting.content_localization_supported_locales = ""
        SiteSetting.ai_translation_enabled = true

        translation = translation_module

        expect(translation["module_enabled"]).to eq(false)
        expect(translation["status"]).to eq("state" => "setup", "note_key" => "no_languages")
      end

      it "cannot be enabled before languages are selected" do
        SiteSetting.content_localization_supported_locales = ""

        expect(translation_module["enabled_setting"]).to include(
          "value" => false,
          "can_enable" => false,
        )
      end

      it "reports the languages and whether readers can see the translations" do
        SiteSetting.content_localization_supported_locales = "de|es"
        SiteSetting.ai_translation_enabled = true
        SiteSetting.content_localization_enabled = false

        translation = translation_module

        expect(translation["module_enabled"]).to eq(true)
        expect(translation["status"]).to eq(
          "state" => "on",
          "label_key" => "on_with_languages",
          "count" => 2,
          "note_key" => "hidden_from_readers",
        )

        SiteSetting.content_localization_enabled = true

        expect(translation_module["status"]).not_to have_key("note_key")
      end

      it "uses the generic status when translation is off" do
        SiteSetting.content_localization_supported_locales = "de"
        SiteSetting.ai_translation_enabled = false

        translation = translation_module

        expect(translation["status"]).to be_nil
        expect(translation["enabled_setting"]).to include("value" => false, "can_enable" => true)
      end
    end

    it "does not expose a toggle for the deprecated Discover feature" do
      enable_legacy_discover

      get "/admin/plugins/discourse-ai/ai-features.json"

      search = response.parsed_body["ai_features"].find { |m| m["module_name"] == "search" }
      features = search["features"].index_by { |f| f["name"] }

      expect(features["discoveries"]["enabled_setting"]).to be_nil
      expect(features["ask_ai"]["enabled_setting"]).to include("name" => "ai_ask_ai_enabled")
    end

    it "does not expose the automation plugin setting as a module toggle" do
      SiteSetting.discourse_automation_enabled = true

      get "/admin/plugins/discourse-ai/ai-features.json"

      automation_modules =
        response.parsed_body["ai_features"].select do |m|
          m["module_name"].start_with?("automation_")
        end

      expect(automation_modules).to be_present
      expect(automation_modules.map { |m| m["enabled_setting"] }).to all(be_nil)
    end

    it "reflects changes to the spam detector agent's default language model" do
      hosted_model = Fabricate(:seeded_model)
      agent_id = DiscourseAi::Agents::Agent.system_agents[DiscourseAi::Agents::SpamDetector]

      put "/admin/plugins/discourse-ai/ai-spam.json",
          params: {
            is_enabled: true,
            llm_model_id: hosted_model.id,
            ai_agent_id: agent_id,
          }

      expect(response.status).to eq(200)
      expect(SiteSetting.ai_spam_detection_enabled).to eq(true)

      put "/admin/plugins/discourse-ai/ai-agents/#{agent_id}.json",
          params: {
            ai_agent: {
              default_llm_id: llm_model.id,
            },
          }

      expect(response.status).to eq(200)
      expect(AiAgent.find(agent_id).default_llm_id).to eq(llm_model.id)

      get "/admin/plugins/discourse-ai/ai-features.json"

      expect(response.status).to eq(200)
      spam_module =
        response.parsed_body["ai_features"].find { |ai_module| ai_module["module_name"] == "spam" }
      spam_feature = spam_module["features"].find { |feature| feature["name"] == "inspect_posts" }

      expect(spam_feature["llm_models"]).to contain_exactly(
        "id" => llm_model.id,
        "name" => llm_model.display_name,
      )
    end

    it "lists mixed sentiment backends independently of workflows without exposing endpoint credentials" do
      decision_model = Fabricate(:decision_model)
      endpoint_config = {
        classification_type: "emotion",
        model_name: "custom/emotion",
        endpoint: "srv://private-classifier.example.com",
        api_key: "private-classifier-key",
      }
      SiteSetting.enable_discourse_workflows = false
      SiteSetting.ai_sentiment_enabled = true
      SiteSetting.ai_sentiment_emotion_enabled = true
      SiteSetting.ai_sentiment_sentiment_classification_strategy = "decision_model"
      SiteSetting.ai_sentiment_sentiment_decision_model = decision_model.id
      SiteSetting.ai_sentiment_model_configs = [endpoint_config].to_json

      get "/admin/plugins/discourse-ai/ai-features.json"

      expect(response.status).to eq(200)
      sentiment_module =
        response.parsed_body["ai_features"].find { |entry| entry["module_name"] == "sentiment" }
      expect(sentiment_module["module_enabled"]).to eq(true)
      expect(sentiment_module["features"]).to contain_exactly(
        {
          "name" => "sentiment",
          "agents" => [],
          "llm_models" => [],
          "enabled" => true,
          "enabled_setting" => {
            "name" => "ai_sentiment_enabled",
            "value" => true,
            "can_enable" => true,
          },
          "backend" => "decision_model",
          "ready" => true,
          "decision_model" => {
            "id" => decision_model.id,
            "display_name" => decision_model.display_name,
          },
        },
        {
          "name" => "emotion",
          "agents" => [],
          "llm_models" => [],
          "enabled" => true,
          "enabled_setting" => {
            "name" => "ai_sentiment_emotion_enabled",
            "value" => true,
            "can_enable" => true,
          },
          "backend" => "classification_model",
          "ready" => true,
          "classification_model" => {
            "model_name" => endpoint_config[:model_name],
          },
        },
      )
      expect(response.body).not_to include(
        endpoint_config[:endpoint],
        endpoint_config[:api_key],
        decision_model.url,
        decision_model.api_key,
      )
    end

    it "keeps enabled sentiment discoverable when its decision model is unconfigured" do
      SiteSetting.ai_sentiment_enabled = true
      SiteSetting.ai_sentiment_sentiment_classification_strategy = "decision_model"

      get "/admin/plugins/discourse-ai/ai-features.json"

      sentiment_module =
        response.parsed_body["ai_features"].find { |entry| entry["module_name"] == "sentiment" }
      expect(sentiment_module["module_enabled"]).to eq(true)
      expect(sentiment_module["features"].find { |entry| entry["name"] == "sentiment" }).to include(
        "enabled" => true,
        "ready" => false,
        "decision_model" => nil,
      )
    end

    it "lists the module as enabled for either capability without coupling the cards" do
      [[true, false], [false, true]].each do |sentiment, emotion|
        SiteSetting.ai_sentiment_enabled = sentiment
        SiteSetting.ai_sentiment_emotion_enabled = emotion

        get "/admin/plugins/discourse-ai/ai-features.json"

        sentiment_module =
          response.parsed_body["ai_features"].find { |entry| entry["module_name"] == "sentiment" }
        expect(sentiment_module["module_enabled"]).to eq(true)
        expect(
          sentiment_module["features"].to_h { |entry| [entry["name"], entry["enabled"]] },
        ).to eq("sentiment" => sentiment, "emotion" => emotion)
      end
    end

    it "includes automation-related features" do
      SiteSetting.discourse_automation_enabled = true

      get "/admin/plugins/discourse-ai/ai-features.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["ai_features"].count).to eq(
        DiscourseAi::Configuration::Module.all.count(&:visible?),
      )
    end
  end

  describe "sentiment background processing settings" do
    it "exposes both controls in the sentiment settings area" do
      get "/admin/config/site_settings.json", params: { filter_area: "ai-features/sentiment" }

      expect(response.status).to eq(200)
      setting_names = response.parsed_body["site_settings"].map { |setting| setting["setting"] }
      expect(setting_names).to include(
        "ai_sentiment_backfill_maximum_posts_per_hour",
        "ai_sentiment_backfill_post_max_age_days",
      )
    end

    it "rejects a negative post age while allowing zero" do
      original_age = SiteSetting.ai_sentiment_backfill_post_max_age_days

      put "/admin/site_settings/ai_sentiment_backfill_post_max_age_days.json",
          params: {
            ai_sentiment_backfill_post_max_age_days: -1,
          }

      expect(response.status).to eq(422)
      expect(SiteSetting.ai_sentiment_backfill_post_max_age_days).to eq(original_age)

      put "/admin/site_settings/ai_sentiment_backfill_post_max_age_days.json",
          params: {
            ai_sentiment_backfill_post_max_age_days: 0,
          }

      expect(response.status).to eq(204)
      expect(SiteSetting.ai_sentiment_backfill_post_max_age_days).to eq(0)
    end
  end

  describe "#edit" do
    it "returns the sentiment configuration module" do
      get "/admin/plugins/discourse-ai/ai-features/#{DiscourseAi::Configuration::Module::SENTIMENT_ID}/edit.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["module_name"]).to eq("sentiment")
      expect(response.parsed_body["module_enabled"]).to eq(false)
      expect(response.parsed_body["features"].map { |entry| entry["enabled"] }).to eq(
        [false, false],
      )
    end

    it "returns a success response" do
      get "/admin/plugins/discourse-ai/ai-features/1/edit.json"
      expect(response.parsed_body["module_name"]).to eq("summarization")
    end
  end
end
