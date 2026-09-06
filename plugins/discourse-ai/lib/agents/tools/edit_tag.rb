# frozen_string_literal: true

module DiscourseAi
  module Agents
    module Tools
      class EditTag < Tool
        def self.signature
          {
            name: name,
            description:
              "Renames an existing tag or changes its description. This edits the tag itself everywhere it is used; use change_topic_tags to change which tags are on a topic.",
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
                description:
                  "The new description for the tag. Pass an empty string to clear the existing description.",
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

          # Invisible tags report not-found so their names cannot be probed.
          if tag.blank? || !guardian.can_see_tag?(tag)
            return error_response(I18n.t("discourse_ai.ai_bot.edit_tag.errors.not_found"))
          end

          if parameters[:new_name].blank? && !description_provided?
            return error_response(I18n.t("discourse_ai.ai_bot.edit_tag.errors.nothing_to_edit"))
          end

          if parameters[:new_name].present? && clean_new_name.blank?
            return(
              error_response(
                I18n.t(
                  "discourse_ai.ai_bot.edit_tag.errors.invalid_new_name",
                  name: parameters[:new_name],
                ),
              )
            )
          end

          if reason.blank?
            return error_response(I18n.t("discourse_ai.ai_bot.edit_tag.errors.no_reason"))
          end

          nil
        end

        def description_args
          { name: parameters[:name], fields: changed_fields.join(", ") }
        end

        private

        def tag
          @tag ||= Tag.where_name(parameters[:name].to_s).first
        end

        def clean_new_name
          @clean_new_name ||= DiscourseTagging.clean_tag(parameters[:new_name].to_s)
        end

        def description_provided?
          !parameters[:description].nil?
        end

        def changed_fields
          fields = []
          fields << "name → #{clean_new_name}" if parameters[:new_name].present?
          fields << "description" if description_provided?
          fields
        end

        def perform_edit
          if !guardian.can_edit_tag?(tag)
            return error_response(I18n.t("discourse_ai.ai_bot.edit_tag.errors.not_allowed"))
          end

          previous_name = tag.name
          tag.name = clean_new_name if parameters[:new_name].present?
          tag.description = parameters[:description].presence if description_provided?

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
