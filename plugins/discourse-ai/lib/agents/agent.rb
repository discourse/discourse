#frozen_string_literal: true

module DiscourseAi
  module Agents
    class Agent
      DELEGATED_IMAGE_PATTERN = %r{!\[[^\]]*\]\((upload://[a-zA-Z0-9]+(?:\.[a-zA-Z0-9]{1,10})?)\)}

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

        def max_turn_tokens
          nil
        end

        def subagent_ids
          []
        end

        def compression_threshold
          nil
        end

        def rag_document_sources
          []
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
          sync_external_registry!
          @system_agents ||= builtin_system_agents
        end

        def system_agents_by_id
          @system_agents_by_id ||= system_agents.invert
        end

        def external_tool_by_name(name)
          sync_external_registry!
          @external_tools_by_name[name]
        end

        def external_tools
          sync_external_registry!
          @external_tools_by_name.values
        end

        def all(user:)
          # listing tools has to be dynamic cause site settings may change
          AiAgent.all_agents.filter do |agent|
            next false if !user.in_any_groups?(agent.allowed_group_ids)

            if agent.system
              instance = agent.new
              instance.required_tools == [] ||
                (instance.required_tools - all_available_tools).empty?
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
            Tools::ListUsers,
            Tools::Time,
            Tools::Search,
            Tools::Read,
            Tools::ReadPost,
            Tools::FlagPost,
            Tools::CloseTopic,
            Tools::SuspendUser,
            Tools::SilenceUser,
            Tools::UnlistTopic,
            Tools::LockPost,
            Tools::DeleteTopic,
            Tools::EditPost,
            Tools::CreateCategory,
            Tools::EditCategory,
            Tools::MoveTopic,
            Tools::SetTopicTimer,
            Tools::SetSlowMode,
            Tools::MovePosts,
            Tools::GrantBadge,
            Tools::ListReviewables,
            Tools::PerformReviewableAction,
            Tools::AddReviewableNote,
            Tools::DbSchema,
            Tools::SearchSettings,
            Tools::SettingContext,
            Tools::ReadSiteSetting,
            Tools::ChangeSiteSetting,
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
            tools << Tools::CreateTag
            tools << Tools::EditTag
            tools << Tools::EditTopicTags
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

        def external_agent_id(agent_klass)
          -(Digest::SHA1.hexdigest(agent_klass.to_s).to_i(16) % 1_000_000 + 1_000_000)
        end

        private

        def sync_external_registry!
          configs = external_feature_configs
          signature = configs.hash
          if @external_registry_signature == signature && @external_tools_by_name && @system_agents
            return
          end

          @external_registry_signature = signature
          external_agents = {}
          external_tools_by_name = {}

          configs.each do |config|
            agent_klass = config[:agent_klass]
            next if agent_klass.nil?
            next if external_agents.key?(agent_klass)
            next if builtin_system_agents.key?(agent_klass)

            external_agents[agent_klass] = config[:agent_id]

            agent_klass.new.tools.each do |tool_klass|
              tool_name = tool_klass.to_s.split("::").last
              next if "DiscourseAi::Agents::Tools::#{tool_name}".safe_constantize
              external_tools_by_name[tool_name] ||= tool_klass
            end
          end

          new_system_agents = builtin_system_agents.merge(external_agents)
          @system_agents_by_id = nil if @system_agents != new_system_agents
          @system_agents = new_system_agents
          @external_tools_by_name = external_tools_by_name
        end

        def external_feature_configs
          return [] if !DiscoursePluginRegistry.respond_to?(:_raw_external_ai_features)

          DiscoursePluginRegistry
            ._raw_external_ai_features
            .pluck(:value)
            .each do |config|
              config[:agent_id] ||= external_agent_id(config[:agent_klass]) if config[:agent_klass]
            end
        end

        def builtin_system_agents
          @builtin_system_agents ||= {
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
            SentimentClassifier => -36,
            EmotionClassifier => -37,
            AdminDashboardHighlights => -38,
            DiscourseAdminAssistant => -39,
          }.freeze
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

      def stop_chain_on_pending_approval?
        false
      end

      def temperature
        nil
      end

      def top_p
        nil
      end

      def thinking_effort
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

      def native_tools
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

      def runtime_tools(llm: nil, context: nil)
        reserved_spawn_agent = self.class.subagent_ids.present?
        tools =
          available_tools.reject do |tool|
            tool_name = tool.signature[:name]
            tool_name == Tools::ViewImage.name ||
              reserved_spawn_agent && tool_name.to_s.casecmp(Tools::SpawnAgent.name).zero?
          end

        if (spawn_agent_tool = spawn_agent_tool_class(context))
          tools.unshift(spawn_agent_tool)
        end

        if automatic_vision_tool_enabled?(context) && llm&.llm_model&.delegated_vision?
          tools << Tools::ViewImage
        end

        tools.uniq { |tool| tool.signature[:name].to_s.downcase }
      end

      def spawn_agent_tool_class(context)
        return if self.class.subagent_ids.blank?
        return if context&.server_owned_tools == false || context&.user.nil?
        return if context.subagent_depth.to_i >= SubagentRunner::MAX_SUBAGENT_DEPTH

        state = context.subagent_execution_state
        if !state&.spawn_available? || !state.completion_available? || state.remaining_tokens <= 0
          return
        end

        records_by_id = AiAgent.where(id: self.class.subagent_ids, enabled: true).index_by(&:id)
        models_by_agent_id = SubagentRunner.resolve_models(records_by_id.values)
        usable_agents =
          self.class.subagent_ids.filter_map do |subagent_id|
            record = records_by_id[subagent_id]
            next if !record
            next if !context.user.in_any_groups?(record.allowed_group_ids)
            next if !models_by_agent_id[subagent_id]
            if record.system?
              required_tools = record.class_instance.new.required_tools
              next if (required_tools - self.class.all_available_tools).present?
            end

            record
          end
        return if usable_agents.empty?

        Tools::SpawnAgent.class_instance(id, usable_agents)
      end

      def automatic_vision_tool_enabled?(context)
        context&.server_owned_tools != false && self.class.vision_enabled
      end

      def defer_forced_tool_for_vision?
        false
      end

      def craft_prompt(context, llm: nil)
        available_tools = runtime_tools(llm: llm, context: context)
        context.runtime_tools = available_tools
        context.runtime_tools_llm_model_id = llm&.llm_model&.id
        messages = delegated_vision_messages(context, llm)
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
            messages: post_system_examples.concat(messages),
            topic_id: context.topic_id,
            post_id: context.post_id,
          )

        prompt.max_pixels = self.class.vision_max_pixels if self.class.vision_enabled
        prompt.tools = available_tools.map(&:signature) if available_tools
        prompt.native_tools = native_tools if native_tools.present?
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

      def delegated_vision_messages(context, llm)
        return context.messages if !automatic_vision_tool_enabled?(context)
        return context.messages if !llm&.llm_model&.delegated_vision?
        return context.messages if !self.class.vision_enabled

        messages = context.messages.deep_dup
        uploads_by_id, uploads_by_sha1 = delegated_vision_uploads(messages)

        messages.map do |message|
          next message if message[:type].to_sym != :user

          message[:content] = delegated_vision_content(
            message[:content],
            context,
            uploads_by_id,
            uploads_by_sha1,
          )
          message
        end
      end

      def delegated_vision_uploads(messages)
        upload_ids = Set.new
        upload_sha1s = Set.new

        messages.each do |message|
          next if message[:type].to_sym != :user

          content_parts = message[:content].is_a?(Array) ? message[:content] : [message[:content]]
          content_parts.each do |part|
            if part.is_a?(Hash) && part.key?(:upload_id)
              upload_ids << part[:upload_id]
            elsif part.is_a?(String)
              part.scan(DELEGATED_IMAGE_PATTERN) do |(short_url)|
                sha1 = Upload.sha1_from_short_url(short_url)
                upload_sha1s << sha1 if sha1
              end
            end
          end
        end

        return {}, {} if upload_ids.empty? && upload_sha1s.empty?

        uploads = Upload.where(id: upload_ids).or(Upload.where(sha1: upload_sha1s)).to_a
        [uploads.index_by(&:id), uploads.index_by(&:sha1)]
      end

      def delegated_vision_content(content, context, uploads_by_id, uploads_by_sha1)
        seen_upload_ids = Set.new

        if content.is_a?(String)
          replace_delegated_image_references(content, context, seen_upload_ids, uploads_by_sha1)
        elsif content.is_a?(Array)
          content.filter_map do |part|
            if part.is_a?(Hash) && part.key?(:upload_id)
              upload = uploads_by_id[part[:upload_id].to_i]
              next part if upload.blank? || !image_upload?(upload)
              next if seen_upload_ids.include?(upload.id)

              delegated_image_handle(upload, context, seen_upload_ids)
            elsif part.is_a?(String)
              replace_delegated_image_references(part, context, seen_upload_ids, uploads_by_sha1)
            else
              part
            end
          end
        else
          content
        end
      end

      def replace_delegated_image_references(content, context, seen_upload_ids, uploads_by_sha1)
        content.gsub(DELEGATED_IMAGE_PATTERN) do |markdown|
          sha1 = Upload.sha1_from_short_url(Regexp.last_match(1))
          upload = uploads_by_sha1[sha1]
          next markdown if upload.blank? || !image_upload?(upload)
          next "" if seen_upload_ids.include?(upload.id)

          delegated_image_handle(upload, context, seen_upload_ids) || "[Image unavailable]"
        end
      end

      def delegated_image_handle(upload, context, seen_upload_ids)
        return if !prompt_guardian(context).can_see_upload?(upload)

        seen_upload_ids << upload.id
        context.register_image_upload(upload.id)
        "[Image available through view_image: upload_id #{upload.id}]"
      end

      def prompt_guardian(context)
        context.image_guardian
      end

      def image_upload?(upload)
        DiscourseAi::Completions::UploadEncoder.image_upload?(upload)
      end

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

        exposed_tools =
          if context&.runtime_tools.present? &&
               context.runtime_tools_llm_model_id == llm&.llm_model&.id
            context.runtime_tools
          else
            available_tools.reject do |tool|
              tool_name = tool.signature[:name]
              tool_name == Tools::ViewImage.name ||
                self.class.subagent_ids.present? &&
                  tool_name.to_s.casecmp(Tools::SpawnAgent.name).zero?
            end
          end
        tool_klass = exposed_tools.find { |tool| tool.signature.dig(:name) == function_name }
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
              if value.is_a?(Array)
                value
              else
                begin
                  JSON.parse(value)
                rescue JSON::ParserError, TypeError
                  [value.to_s]
                end
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
