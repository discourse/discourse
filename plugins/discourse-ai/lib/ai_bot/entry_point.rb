# frozen_string_literal: true

module DiscourseAi
  module AiBot
    class EntryPoint
      Bot = Struct.new(:id, :name, :llm)

      def self.all_bot_ids
        historical_bot_user_ids
      end

      def self.historical_bot_user_ids(topic: nil)
        ids =
          AiAgent
            .with_user
            .pluck(:user_id)
            .concat(LlmModel.with_user.pluck(:user_id))
            .concat(UserCustomField.where(name: HISTORICAL_AI_USER_CUSTOM_FIELD).pluck(:user_id))
        if topic
          ids.concat(
            topic
              .posts
              .joins(:_custom_fields)
              .where(
                post_custom_fields: {
                  name: [
                    POST_AI_AGENT_ID_FIELD,
                    POST_AI_LLM_MODEL_ID_FIELD,
                    POST_AI_LLM_NAME_FIELD,
                  ],
                },
              )
              .where("posts.user_id <= 0")
              .pluck(:user_id),
          )
        end
        ids.compact.uniq
      end

      def self.ai_response?(post)
        return false if post.blank?
        return true if historical_bot_user_ids(topic: post.topic).include?(post.user_id)

        post.user_id.to_i <= 0 &&
          post.custom_fields.slice(POST_AI_AGENT_ID_FIELD, POST_AI_LLM_NAME_FIELD).present?
      end

      def self.find_participant_in(participant_ids)
        model = LlmModel.includes(:user).where(user_id: participant_ids).last
        return if model.nil?

        bot_user = model.user

        Bot.new(bot_user.id, bot_user.username_lower, model.name)
      end

      def self.find_user_from_model(model_name)
        # Hack(Roman): Added this because Command R Plus had a different in the bot settings.
        # Will eventually amend it with a data migration.
        name = model_name
        name = "command-r-plus" if name == "cohere-command-r-plus"

        LlmModel.joins(:user).where(name: name).last&.user
      end

      def self.available_agents(user)
        classes_by_id = DiscourseAi::Agents::Agent.all(user: user).index_by(&:id)
        agent_users = AiAgent.agent_users(user: user)
        model_names =
          LlmModel
            .where(id: agent_users.filter_map { |agent| agent[:default_llm_id] })
            .pluck(:id, :display_name)
            .to_h

        agent_users.filter_map do |agent_user|
          agent = classes_by_id[agent_user[:id]]
          next if agent.blank? || agent_user[:username].blank?

          {
            id: agent.id,
            user_id: agent_user[:user_id],
            name: agent.name,
            description: agent.description,
            default_llm_id: agent_user[:default_llm_id],
            default_llm_name: model_names[agent_user[:default_llm_id]],
            has_default_llm:
              agent_user[:default_llm_id].present? || SiteSetting.ai_default_llm_model.present?,
            force_default_llm: agent_user[:force_default_llm],
            username: agent_user[:username],
            allow_personal_messages: agent_user[:allow_personal_messages],
          }
        end
      end

      def self.available_llm_models
        enabled_ids = LlmModel.enabled_chat_bot_ids
        return [] if enabled_ids.empty?

        LlmModel
          .where(id: enabled_ids)
          .order(:display_name)
          .map do |model|
            {
              "id" => model.id,
              "model_name" => model.name,
              "display_name" => model.display_name,
              "vision_enabled" => model.agent_image_capable?,
              "legacy_user_id" => model.user_id,
            }.compact
          end
      end

      def self.enabled_user_ids_and_models_map
        available_llm_models
      end

      def self.personal_message_bot_user_ids(user)
        return [] if user.blank? || !SiteSetting.ai_bot_enabled
        return [] if !user.in_any_groups?(SiteSetting.ai_bot_allowed_groups_map)

        AiAgent
          .allowed_modalities(user: user, allow_personal_messages: true)
          .map { |agent| agent[:user_id] }
          .compact
      end

      # Most errors are simply "not_allowed"
      # we do not want to reveal information about this system
      # the 2 exceptions are "other_people_in_pm" and "other_content_in_pm"
      # in both cases you have access to the PM so we are not revealing anything
      def self.ai_share_error(topic, guardian)
        return nil if guardian.can_share_ai_bot_conversation?(topic)

        return :not_allowed if !guardian.can_see?(topic)

        # other people in PM
        if topic.topic_allowed_users.where("user_id > 0 and user_id <> ?", guardian.user.id).exists?
          return :other_people_in_pm
        end

        # other content in PM
        if topic.posts.where("user_id > 0 and user_id <> ?", guardian.user.id).exists?
          return :other_content_in_pm
        end

        :not_allowed
      end

      def inject_into(plugin)
        # Long term we need a better API here
        # we only want to load this custom field for bots
        TopicView.default_post_custom_fields.concat(
          [
            POST_AI_LLM_NAME_FIELD,
            POST_AI_LLM_MODEL_ID_FIELD,
            POST_AI_AGENT_ID_FIELD,
            POST_AI_AGENT_AUTHORIZATION_USER_ID_FIELD,
          ],
        )

        plugin.register_topic_custom_field_type(TOPIC_AI_BOT_PM_FIELD, :string)

        # Hide bot PMs from the personal inbox queries (Latest, New, Unread)
        # so human conversations are not buried under bot replies. Sent and
        # Archive are intentionally untouched.
        plugin.register_modifier(:private_messages_personal_inbox_query) do |list, _user|
          next list unless SiteSetting.ai_bot_enabled

          list.where(<<~SQL, field: TOPIC_AI_BOT_PM_FIELD)
            NOT EXISTS (
              SELECT 1 FROM topic_custom_fields tcf_pm_inbox
              WHERE tcf_pm_inbox.topic_id = topics.id
              AND tcf_pm_inbox.name = :field
              AND tcf_pm_inbox.value = 't'
            )
          SQL
        end

        plugin.register_modifier(:guardian_can_send_private_message_to_target) do |allowed, params|
          allowed ||
            (
              params[:private_message_context] == PERSONAL_MESSAGE_CONTEXT &&
                params[:guardian].can_send_pm_to_ai_bot?(params[:target])
            )
        end

        plugin.on(:topic_created) do |topic|
          next if !topic.private_message?
          creator = topic.user

          # Only process if creator is not a bot or system user
          next if DiscourseAi::AiBot::Playground.is_bot_user_id?(creator.id)

          # Get all bot user IDs defined by the discourse-ai plugin
          bot_ids = DiscourseAi::AiBot::EntryPoint.all_bot_ids

          # Check if the only recipients are bots
          recipients = topic.topic_allowed_users.pluck(:user_id)

          # Remove creator from recipients for checking
          recipients -= [creator.id]

          # If all remaining recipients are AI bots and there's exactly one recipient
          if recipients.length == 1 && (recipients - bot_ids).empty?
            # The only recipient is an AI bot - add the custom field to the topic
            topic.custom_fields[TOPIC_AI_BOT_PM_FIELD] = true

            # Save the custom fields
            topic.save_custom_fields
          end
        end

        plugin.register_modifier(:chat_allowed_bot_user_ids) do |user_ids, guardian|
          if guardian.user
            allowed_chat =
              AiAgent.allowed_modalities(
                user: guardian.user,
                allow_chat_direct_messages: true,
                allow_chat_channel_mentions: true,
              )
            allowed_bot_ids = allowed_chat.map { |info| info[:user_id] }
            user_ids.concat(allowed_bot_ids)
          end
          user_ids
        end

        Oneboxer.register_local_handler(
          "discourse_ai/ai_bot/shared_ai_conversations",
        ) do |url, route|
          if route[:action] == "show" && share_key = route[:share_key]
            if conversation = SharedAiConversation.find_by(share_key: share_key)
              conversation.onebox if conversation.publicly_visible?
            end
          end
        end

        plugin.on(:reduce_excerpt) do |doc, options|
          doc.css("details").remove if options && options[:strip_details]
        end

        plugin.register_seedfu_fixtures(Rails.root.join("plugins/discourse-ai/db/fixtures/ai_bot"))

        plugin.add_to_serializer(
          :topic_view,
          :is_bot_pm,
          include_condition: -> do
            object.topic && object.topic.private_message? &&
              object.topic.custom_fields[TOPIC_AI_BOT_PM_FIELD]
          end,
        ) { true }

        plugin.add_to_serializer(
          :post,
          :llm_name,
          include_condition: -> do
            object.user_id.to_i <= 0 && object.custom_fields[POST_AI_LLM_NAME_FIELD].present?
          end,
        ) { object.custom_fields[POST_AI_LLM_NAME_FIELD] }

        plugin.add_to_serializer(
          :post,
          :ai_llm_model_id,
          include_condition: -> do
            object.user_id.to_i <= 0 && object.custom_fields[POST_AI_LLM_MODEL_ID_FIELD].present?
          end,
        ) { object.custom_fields[POST_AI_LLM_MODEL_ID_FIELD].to_i }

        plugin.add_to_serializer(
          :post,
          :ai_agent_id,
          include_condition: -> do
            object.user_id.to_i <= 0 && object.custom_fields[POST_AI_AGENT_ID_FIELD].present?
          end,
        ) { object.custom_fields[POST_AI_AGENT_ID_FIELD].to_i }

        plugin.add_to_serializer(
          :post,
          :ai_agent_name,
          include_condition: -> do
            object.user_id.to_i <= 0 && object.custom_fields[POST_AI_AGENT_ID_FIELD].present?
          end,
        ) { AiAgent.find_by_id_from_cache(object.custom_fields[POST_AI_AGENT_ID_FIELD].to_i)&.name }

        plugin.add_to_serializer(
          :current_user,
          :ai_enabled_agents,
          include_condition: -> { scope.authenticated? },
        ) { DiscourseAi::AiBot::EntryPoint.available_agents(scope.user) }

        plugin.add_to_serializer(
          :current_user,
          :can_debug_ai_bot_conversations,
          include_condition: -> do
            SiteSetting.ai_bot_enabled && scope.authenticated? &&
              SiteSetting.ai_bot_debugging_allowed_groups.present? &&
              scope.user.in_any_groups?(SiteSetting.ai_bot_debugging_allowed_groups_map)
          end,
        ) { true }

        plugin.add_to_serializer(
          :current_user,
          :ai_available_llm_models,
          include_condition: -> do
            SiteSetting.ai_bot_enabled && scope.authenticated? &&
              scope.user.in_any_groups?(SiteSetting.ai_bot_allowed_groups_map)
          end,
        ) { DiscourseAi::AiBot::EntryPoint.available_llm_models }

        plugin.add_to_serializer(
          :current_user,
          :ai_enabled_chat_bots,
          include_condition: -> do
            SiteSetting.ai_bot_enabled && scope.authenticated? &&
              scope.user.in_any_groups?(SiteSetting.ai_bot_allowed_groups_map)
          end,
        ) do
          AiAgent
            .agent_users(user: scope.user)
            .filter_map do |agent_user|
              next if agent_user[:username].blank?

              {
                "id" => agent_user[:user_id],
                "agent_id" => agent_user[:id],
                "username" => agent_user[:username],
                "has_default_llm" =>
                  agent_user[:default_llm_id].present? || SiteSetting.ai_default_llm_model.present?,
                "force_default_llm" => agent_user[:force_default_llm],
                "is_agent" => true,
              }
            end
        end

        plugin.add_to_serializer(
          :"chat/message",
          :ai_llm_name,
          include_condition: -> do
            object.user_id.to_i <= 0 &&
              object.custom_fields[CHAT_MESSAGE_AI_LLM_NAME_FIELD].present?
          end,
        ) { object.custom_fields[CHAT_MESSAGE_AI_LLM_NAME_FIELD] }

        plugin.add_to_serializer(
          :"chat/message",
          :ai_llm_model_id,
          include_condition: -> do
            object.user_id.to_i <= 0 &&
              object.custom_fields[CHAT_MESSAGE_AI_LLM_MODEL_ID_FIELD].present?
          end,
        ) { object.custom_fields[CHAT_MESSAGE_AI_LLM_MODEL_ID_FIELD].to_i }

        plugin.add_to_serializer(
          :"chat/message",
          :ai_agent_id,
          include_condition: -> do
            object.user_id.to_i <= 0 &&
              object.custom_fields[CHAT_MESSAGE_AI_AGENT_ID_FIELD].present?
          end,
        ) { object.custom_fields[CHAT_MESSAGE_AI_AGENT_ID_FIELD].to_i }

        plugin.add_to_serializer(:current_user, :can_share_ai_bot_conversations) do
          scope.user.in_any_groups?(SiteSetting.ai_bot_public_sharing_allowed_groups_map)
        end

        plugin.add_to_serializer(
          :topic_view,
          :ai_agent_id,
          include_condition: -> do
            SiteSetting.ai_bot_enabled &&
              object.topic.custom_fields[TOPIC_AI_AGENT_ID_FIELD].present?
          end,
        ) { object.topic.custom_fields[TOPIC_AI_AGENT_ID_FIELD].to_i }

        plugin.add_to_serializer(
          :topic_view,
          :ai_llm_model_id,
          include_condition: -> do
            SiteSetting.ai_bot_enabled &&
              object.topic.custom_fields[TOPIC_AI_LLM_MODEL_ID_FIELD].present?
          end,
        ) { object.topic.custom_fields[TOPIC_AI_LLM_MODEL_ID_FIELD].to_i }

        plugin.add_to_serializer(
          :topic_view,
          :ai_agent_name,
          include_condition: -> { SiteSetting.ai_bot_enabled && object.topic.private_message? },
        ) do
          topic = object.topic
          id = topic.custom_fields[TOPIC_AI_AGENT_ID_FIELD]
          name = DiscourseAi::Agents::Agent.find_by(user: scope.user, id: id.to_i)&.name if id
          name || topic.custom_fields["ai_agent"]
        end

        plugin.on(:post_created) do |post, opts, user|
          DiscourseAi::AiBot::Playground.schedule_reply(
            post,
            authorization_user: user || post.user,
            requested_agent_id: opts[:ai_agent_id],
            requested_model_id: opts[:ai_llm_model_id],
          )
        end

        plugin.on(:chat_message_created) do |chat_message, channel, user, context|
          DiscourseAi::AiBot::Playground.schedule_chat_reply(chat_message, channel, user, context)
        end

        plugin.on(:chat_message_interaction) do |interaction|
          DiscourseAi::AiBot::ChatToolApproval.handle_interaction(interaction)
        end

        plugin.add_permitted_post_create_param(:ai_agent_id)
        plugin.add_permitted_post_create_param(:ai_llm_model_id)
        plugin.register_editable_topic_custom_field(TOPIC_AI_AGENT_ID_FIELD.to_sym)
        plugin.register_topic_custom_field_type(
          TOPIC_AI_AGENT_ID_FIELD.to_sym,
          :string,
          max_length: TOPIC_AI_FIELD_ID_MAX_LENGTH,
        )
        plugin.register_editable_topic_custom_field(TOPIC_AI_LLM_MODEL_ID_FIELD.to_sym)
        plugin.register_topic_custom_field_type(TOPIC_AI_LLM_MODEL_ID_FIELD.to_sym, :integer)

        plugin.on(:after_validate_topic) do |topic, topic_creator|
          DiscourseAi::AiBot::TopicAgentValidator.validate(topic, topic_creator)
        end

        plugin.add_api_key_scope(
          :ai,
          { stream_completion: { actions: %w[discourse_ai/admin/ai_agents#stream_reply] } },
        )

        plugin.on(:site_setting_changed) do |name, old_value, new_value|
          if name == :ai_embeddings_selected_model && DiscourseAi::Embeddings.enabled? &&
               new_value != old_value
            RagDocumentFragment.delete_all
            UploadReference
              .where(target: AiAgent.all)
              .each do |ref|
                Jobs.enqueue(
                  :digest_rag_upload,
                  target_type: ref.target_type,
                  target_id: ref.target_id,
                  ai_agent_id: ref.target_id,
                  upload_id: ref.upload_id,
                )
              end
          end
        end
      end
    end
  end
end
