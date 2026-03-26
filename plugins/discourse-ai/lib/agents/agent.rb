#frozen_string_literal: true

module DiscourseAi
  module Agents
    class Agent
      # reserved agent IDs for external plugins
      # discourse-ai system agents use -1 to -499, external plugins use -500 and below
      RESERVED_EXTERNAL_AGENT_IDS = { data_explorer_query_generator: -501 }

      class << self
        def default_enabled
          true
        end

        def rag_conversation_chunks
          10
        end

        def vision_enabled
          false
        end

        def vision_max_pixels
          1_048_576
        end

        def execution_mode
          "default"
        end

        def max_turn_tokens
          nil
        end

        def compression_threshold
          nil
        end

        def force_default_llm
          false
        end

        def allow_chat_channel_mentions
          false
        end

        def allow_chat_direct_messages
          false
        end

        def system_agents
          @system_agents ||= {
            General => -1,
            SqlHelper => -2,
            Artist => -3,
            SettingsExplorer => -4,
            Researcher => -5,
            Creative => -6,
            DiscourseHelper => -8,
            GithubHelper => -9,
            WebArtifactCreator => -10,
            Summarizer => -11,
            ShortSummarizer => -12,
            Designer => -13,
            ForumResearcher => -14,
            ConceptFinder => -15,
            ConceptMatcher => -16,
            ConceptDeduplicator => -17,
            CustomPrompt => -18,
            SmartDates => -19,
            MarkdownTableGenerator => -20,
            PostIllustrator => -21,
            Proofreader => -22,
            TitlesGenerator => -23,
            Tutor => -24,
            Translator => -25,
            ImageCaptioner => -26,
            LocaleDetector => -27,
            PostRawTranslator => -28,
            TopicTitleTranslator => -29,
            ShortTextTranslator => -30,
            SpamDetector => -31,
            ContentCreator => -32,
            ReportRunner => -33,
            Discover => -34,
            ChatThreadTitler => -35,
          }
        end

        def register_system_agent(klass, id)
          system_agents[klass] = id
          @system_agents_by_id = nil
        end

        def system_agents_by_id
          @system_agents_by_id ||= system_agents.invert
        end

        def all(user:)
          # listing tools has to be dynamic cause site settings may change
          AiAgent.all_agents.filter do |agent|
            next false if !user.in_any_groups?(agent.allowed_group_ids)

            if agent.system
              instance = agent.new
              (
                instance.required_tools == [] ||
                  (instance.required_tools - all_available_tools).empty?
              )
            else
              true
            end
          end
        end

        def find_by(id: nil, name: nil, user:)
          all(user: user).find { |agent| agent.id == id || agent.name == name }
        end

        def name
          I18n.t("discourse_ai.ai_bot.agents.#{to_s.demodulize.underscore}.name")
        end

        def description
          I18n.t("discourse_ai.ai_bot.agents.#{to_s.demodulize.underscore}.description")
        end

        def all_available_tools
          tools = [
            Tools::ListCategories,
            Tools::Time,
            Tools::Search,
            Tools::Read,
            Tools::FlagPost,
            Tools::CloseTopic,
            Tools::UnlistTopic,
            Tools::LockPost,
            Tools::DeleteTopic,
            Tools::EditPost,
            Tools::EditCategory,
            Tools::SetTopicTimer,
            Tools::SetSlowMode,
            Tools::MovePosts,
            Tools::GrantBadge,
            Tools::DbSchema,
            Tools::SearchSettings,
            Tools::SettingContext,
            Tools::RandomPicker,
            Tools::DiscourseMetaSearch,
            Tools::GithubFileContent,
            Tools::GithubDiff,
            Tools::GithubSearchFiles,
            Tools::WebBrowser,
            Tools::JavascriptEvaluator,
            Tools::Researcher,
          ]

          if SiteSetting.ai_artifact_security.in?(%w[lax hybrid strict])
            tools << Tools::CreateArtifact
            tools << Tools::UpdateArtifact
            tools << Tools::ReadArtifact
          end

          tools << Tools::GithubSearchCode if SiteSetting.ai_bot_github_access_token.present?

          if SiteSetting.tagging_enabled
            tools << Tools::ListTags
            tools << Tools::EditTags
          end

          # Image generation tools - use custom UI-configured tools
          if Tools::Tool.available_custom_image_tools.present?
            tools << Tools::Image
            tools << Tools::CreateImage
            tools << Tools::EditImage
          end

          if SiteSetting.ai_google_custom_search_api_key.present? &&
               SiteSetting.ai_google_custom_search_cx.present?
            tools << Tools::Google
          end

          tools << Tools::Assign if defined?(::Assigner)
          tools << Tools::MarkAsSolved if defined?(::DiscourseSolved)

          tools
        end
      end

      def id
        @ai_agent&.id || self.class.system_agents[self.class.superclass] ||
          self.class.system_agents[self.class]
      end

      def tools
        []
      end

      def force_tool_use
        []
      end

      def forced_tool_count
        -1
      end

      def required_tools
        []
      end

      def temperature
        nil
      end

      def top_p
        nil
      end

      def options
        {}
      end

      def response_format
        nil
      end

      def examples
        []
      end

      def available_tools
        self
          .class
          .all_available_tools
          .filter { |tool| tools.include?(tool) }
          .concat(tools.filter(&:custom?))
          .tap do |available_tools|
            next if !rag_tool_available?
            if available_tools.any? { |tool|
                 tool.signature[:name] == Tools::SearchUploadedDocuments.name
               }
              next
            end

            available_tools << Tools::SearchUploadedDocuments
          end
          .uniq
      end

      def craft_prompt(context, llm: nil)
        available_tools = self.available_tools
        system_insts = replace_placeholders(system_prompt, context)

        prompt_insts = <<~TEXT.strip
          #{system_insts}
          #{available_tools.map(&:custom_system_message).compact_blank.join("\n")}
          TEXT

        if context.custom_instructions.present?
          prompt_insts << "\n"
          prompt_insts << context.custom_instructions
        end

        post_system_examples = []

        if examples.present?
          examples.flatten.each_with_index do |e, idx|
            post_system_examples << {
              content: replace_placeholders(e, context),
              type: (idx + 1).odd? ? :user : :model,
            }
          end
        end

        prompt =
          DiscourseAi::Completions::Prompt.new(
            prompt_insts,
            messages: post_system_examples.concat(context.messages),
            topic_id: context.topic_id,
            post_id: context.post_id,
          )

        prompt.max_pixels = self.class.vision_max_pixels if self.class.vision_enabled
        prompt.tools = available_tools.map(&:signature) if available_tools
        available_tools.each do |tool|
          tool.inject_prompt(prompt: prompt, context: context, agent: self)
        end
        prompt
      end

      def find_tool(partial, bot_user:, llm:, context:, existing_tools: [])
        return nil if !partial.is_a?(DiscourseAi::Completions::ToolCall)
        tool_instance(
          partial,
          bot_user: bot_user,
          llm: llm,
          context: context,
          existing_tools: existing_tools,
        )
      end

      def allow_partial_tool_calls?
        available_tools.any? { |tool| tool.allow_partial_tool_calls? }
      end

      protected

      def replace_placeholders(content, context)
        replaced =
          content.gsub(/\{(\w+)\}/) do |match|
            found = context.lookup_template_param(match[1..-2])
            found.nil? ? match : found.to_s
          end

        return replaced if !context.format_dates

        DiscourseAi::AiHelper::DateFormatter.process_date_placeholders(replaced, context.user)
      end

      def tool_instance(tool_call, bot_user:, llm:, context:, existing_tools:)
        function_id = tool_call.id
        function_name = tool_call.name
        return nil if function_name.nil?

        tool_klass = available_tools.find { |c| c.signature.dig(:name) == function_name }
        return nil if tool_klass.nil?

        arguments =
          if tool_klass.signature[:json_schema]
            tool_call.parameters
          else
            coerce_tool_arguments(tool_klass.signature[:parameters].to_a, tool_call)
          end

        tool_instance =
          existing_tools.find { |t| t.name == function_name && t.tool_call_id == function_id }

        if tool_instance
          tool_instance.parameters = arguments
          tool_instance.provider_data = tool_call.provider_data if tool_instance.respond_to?(
            :provider_data=,
          )
          tool_instance
        else
          tool_klass.new(
            arguments,
            tool_call_id: function_id || function_name,
            agent_options: options[tool_klass].to_h,
            bot_user: bot_user,
            llm: llm,
            context: context,
            provider_data: tool_call.provider_data,
            agent: self,
          )
        end
      end

      def rag_tool_available?
        return false if !DiscourseAi::Embeddings.enabled?
        return false if id.blank?

        UploadReference.where(target_id: id, target_type: "AiAgent").exists?
      end

      def coerce_tool_arguments(param_defs, tool_call)
        arguments = {}
        param_defs.each do |param|
          name = param[:name]
          value = tool_call.parameters[name.to_sym]

          if param[:type] == "array" && value
            value =
              begin
                JSON.parse(value)
              rescue JSON::ParserError
                [value.to_s]
              end
          elsif param[:type] == "string" && value
            value = strip_quotes(value).to_s
          elsif param[:type] == "integer" && value
            value = strip_quotes(value).to_i
          end

          value = nil if param[:enum] && value && !param[:enum].include?(value)

          arguments[name.to_sym] = value if value
        end
        arguments
      end

      def strip_quotes(value)
        if value.is_a?(String)
          if value.start_with?('"') && value.end_with?('"')
            value = value[1..-2]
          elsif value.start_with?("'") && value.end_with?("'")
            value = value[1..-2]
          else
            value
          end
        else
          value
        end
      end
    end
  end
end
