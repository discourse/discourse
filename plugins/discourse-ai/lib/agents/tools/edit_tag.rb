# frozen_string_literal: true

module DiscourseAi
  module Agents
    module Tools
      class EditTag < Tool
        def self.signature
          {
            name: name,
            description:
              "Renames an existing tag or changes its description. This edits the tag itself everywhere it is used; use edit_tags to change which tags are on a topic.",
            parameters: [
              {
                name: "name",
                description: "The current name of the tag to edit",
                type: "string",
                required: true,
              },
              { name: "new_name", description: "The new name for the tag", type: "string" },
              {
                name: "description",
                description: "The new description for the tag",
                type: "string",
              },
              {
                name: "reason",
                description: "Short explanation of why the tag is being edited",
                type: "string",
                required: true,
              },
            ],
          }
        end

        def self.name
          "edit_tag"
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
          perform_edit
        end

        def validation_error
          if !SiteSetting.tagging_enabled
            return error_response(I18n.t("discourse_ai.ai_bot.edit_tag.errors.tagging_disabled"))
          end

          if tag.blank?
            return error_response(I18n.t("discourse_ai.ai_bot.edit_tag.errors.not_found"))
          end

          if parameters[:new_name].blank? && parameters[:description].blank?
            return error_response(I18n.t("discourse_ai.ai_bot.edit_tag.errors.nothing_to_edit"))
          end

          if reason.blank?
            return error_response(I18n.t("discourse_ai.ai_bot.edit_tag.errors.no_reason"))
          end

          nil
        end

        def description_args
          { name: parameters[:name] }
        end

        private

        def tag
          @tag ||= Tag.where_name(parameters[:name].to_s).first
        end

        def perform_edit
          if !guardian.can_edit_tag?(tag)
            return error_response(I18n.t("discourse_ai.ai_bot.edit_tag.errors.not_allowed"))
          end

          previous_name = tag.name
          tag.name = DiscourseTagging.clean_tag(parameters[:new_name]) if parameters[
            :new_name
          ].present?
          tag.description = parameters[:description] if parameters[:description].present?

          if tag.save
            if tag.name != previous_name
              StaffActionLogger.new(guardian.user).log_custom(
                "renamed_tag",
                previous_value: previous_name,
                new_value: tag.name,
              )
            end
            {
              status: "success",
              tag_name: tag.name,
              message: I18n.t("discourse_ai.ai_bot.edit_tag.success", name: tag.name),
            }
          else
            error_response(tag.errors.full_messages.to_sentence)
          end
        end
      end
    end
  end
end
