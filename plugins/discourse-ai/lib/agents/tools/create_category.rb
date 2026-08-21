# frozen_string_literal: true

module DiscourseAi
  module Agents
    module Tools
      class CreateCategory < Tool
        def self.signature
          {
            name: name,
            description:
              "Creates a new category. Create parent categories before their subcategories, and use list_categories to find parent category IDs.",
            parameters: [
              {
                name: "name",
                description: "The display name for the new category",
                type: "string",
                required: true,
              },
              {
                name: "description",
                description: "A description for the new category",
                type: "string",
              },
              {
                name: "parent_category_id",
                description: "The ID of the parent category, when creating a subcategory",
                type: "integer",
              },
              {
                name: "color",
                description:
                  "The background color, as a 6 digit hex code (e.g. 0088CC). Defaults to the site default when omitted.",
                type: "string",
              },
              {
                name: "text_color",
                description: "The text color, as a 6 digit hex code (e.g. FFFFFF)",
                type: "string",
              },
              {
                name: "reason",
                description: "Short explanation of why the category is being created",
                type: "string",
                required: true,
              },
            ],
          }
        end

        def self.name
          "create_category"
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
          if parameters[:name].blank?
            return error_response(I18n.t("discourse_ai.ai_bot.create_category.errors.no_name"))
          end

          if parameters[:parent_category_id].present? && parent_category.blank?
            return(
              error_response(I18n.t("discourse_ai.ai_bot.create_category.errors.parent_not_found"))
            )
          end

          if reason.blank?
            return error_response(I18n.t("discourse_ai.ai_bot.create_category.errors.no_reason"))
          end

          nil
        end

        def description_args
          { name: parameters[:name] }
        end

        private

        def parent_category
          @parent_category ||= Category.find_by(id: parameters[:parent_category_id])
        end

        def perform_create
          if !guardian.can_create_category?
            return error_response(I18n.t("discourse_ai.ai_bot.create_category.errors.not_allowed"))
          end

          attributes = {
            name: parameters[:name],
            description: parameters[:description].presence,
            parent_category_id: parent_category&.id,
            user: guardian.user,
          }
          %i[color text_color].each do |param|
            value = parameters[param]
            attributes[param] = value.to_s.delete_prefix("#") if value.present?
          end

          category = Category.new(attributes)

          if category.save
            StaffActionLogger.new(guardian.user).log_category_creation(category)
            {
              status: "success",
              category_id: category.id,
              url: category.url,
              message: I18n.t("discourse_ai.ai_bot.create_category.success", name: category.name),
            }
          else
            error_response(category.errors.full_messages.to_sentence)
          end
        end
      end
    end
  end
end
