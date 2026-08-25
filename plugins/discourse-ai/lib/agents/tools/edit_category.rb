# frozen_string_literal: true

module DiscourseAi
  module Agents
    module Tools
      class EditCategory < Tool
        EDITABLE_PARAMS = %i[name description color text_color].freeze

        def self.signature
          {
            name: name,
            description:
              "Edits an existing category's name, description, or colors. At least one editable field must be provided.",
            parameters: [
              {
                name: "category_id",
                description: "The ID of the category to edit",
                type: "integer",
                required: true,
              },
              {
                name: "name",
                description: "The new display name for the category",
                type: "string",
              },
              {
                name: "description",
                description:
                  "The new description for the category. Pass an empty string to clear the existing description.",
                type: "string",
              },
              {
                name: "color",
                description: "The new background color, as a 6 digit hex code (e.g. 0088CC)",
                type: "string",
              },
              {
                name: "text_color",
                description: "The new text color, as a 6 digit hex code (e.g. FFFFFF)",
                type: "string",
              },
              {
                name: "reason",
                description: "Short explanation of why the category is being edited",
                type: "string",
                required: true,
              },
            ],
          }
        end

        def self.name
          "edit_category"
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
          if category.blank?
            return error_response(I18n.t("discourse_ai.ai_bot.edit_category.errors.not_found"))
          end

          if changes.blank?
            return(
              error_response(I18n.t("discourse_ai.ai_bot.edit_category.errors.nothing_to_edit"))
            )
          end

          if reason.blank?
            return error_response(I18n.t("discourse_ai.ai_bot.edit_category.errors.no_reason"))
          end

          if (error = invalid_changes_error)
            return error
          end

          nil
        end

        def description_args
          { category_id: parameters[:category_id], fields: changes.keys.join(", ") }
        end

        private

        def category
          @category ||= Category.find_by(id: parameters[:category_id])
        end

        def changes
          @changes ||=
            EDITABLE_PARAMS
              .filter_map do |param|
                value = parameters[param]
                if param == :description
                  # An explicitly provided empty description clears it.
                  next if value.nil?
                else
                  next if value.blank?
                end
                value = value.to_s.delete_prefix("#") if %i[color text_color].include?(param)
                [param, value]
              end
              .to_h
        end

        # Runs the model validations against the unsaved changes so an invalid
        # request is rejected before it is queued for approval, instead of
        # producing a review item that could only fail.
        def invalid_changes_error
          category.assign_attributes(changes)
          error = error_response(category.errors.full_messages.to_sentence) if !category.valid?
          category.restore_attributes
          error
        end

        def perform_edit
          if !guardian.can_edit_category?(category)
            return error_response(I18n.t("discourse_ai.ai_bot.edit_category.errors.not_allowed"))
          end

          if category.update(changes)
            StaffActionLogger.new(guardian.user).log_category_settings_change(
              category,
              changes.stringify_keys,
              old_permissions: {
              },
            )
            {
              status: "success",
              message: I18n.t("discourse_ai.ai_bot.edit_category.success", name: category.name),
            }
          else
            error_response(category.errors.full_messages.to_sentence)
          end
        end
      end
    end
  end
end
