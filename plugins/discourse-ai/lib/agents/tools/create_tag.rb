# frozen_string_literal: true

module DiscourseAi
  module Agents
    module Tools
      class CreateTag < Tool
        def self.signature
          {
            name: name,
            description:
              "Creates a new tag without applying it to any topic. Use edit_topic_tags to apply tags to a topic.",
            parameters: [
              {
                name: "name",
                description: "The name for the new tag",
                type: "string",
                required: true,
              },
              {
                name: "description",
                description: "A short description for the new tag",
                type: "string",
              },
              {
                name: "reason",
                description: "Short explanation of why the tag is being created",
                type: "string",
                required: true,
              },
            ],
          }
        end

        def self.name
          "create_tag"
        end

        def self.requires_approval?
          true
        end

        def self.attribute_to_approver?
          true
        end

        def invoke
          if (error = validation_error)
            return error
          end
          perform_create
        end

        def validation_error
          if !SiteSetting.tagging_enabled
            return(error_response(I18n.t("discourse_ai.ai_bot.create_tag.errors.tagging_disabled")))
          end

          if clean_name.blank?
            return error_response(I18n.t("discourse_ai.ai_bot.create_tag.errors.no_name"))
          end

          if Tag.where_name(clean_name).exists?
            return(
              error_response(
                I18n.t("discourse_ai.ai_bot.create_tag.errors.already_exists", name: clean_name),
              )
            )
          end

          if reason.blank?
            return error_response(I18n.t("discourse_ai.ai_bot.create_tag.errors.no_reason"))
          end

          nil
        end

        def description_args
          { name: parameters[:name] }
        end

        private

        def clean_name
          @clean_name ||= DiscourseTagging.clean_tag(parameters[:name].to_s)
        end

        def perform_create
          if !guardian.can_admin_tags?
            return error_response(I18n.t("discourse_ai.ai_bot.create_tag.errors.not_allowed"))
          end

          tag = Tag.new(name: clean_name, description: parameters[:description].presence)

          if tag.save
            StaffActionLogger.new(guardian.user).log_custom("created_tag", subject: tag.name)
            {
              status: "success",
              tag_name: tag.name,
              message: I18n.t("discourse_ai.ai_bot.create_tag.success", name: tag.name),
            }
          else
            error_response(tag.errors.full_messages.to_sentence)
          end
        end
      end
    end
  end
end
