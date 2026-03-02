# frozen_string_literal: true

module DiscourseSolved
  module Categories
    module Types
      class Support < ::Categories::Types::Base
        type_id :support

        class << self
          def enable_plugin
            SiteSetting.solved_enabled = true
          end

          def category_matches?(category)
            category.custom_fields[DiscourseSolved::ENABLE_ACCEPTED_ANSWERS_CUSTOM_FIELD] == "true"
          end

          def configure_category(category, configuration_values: {})
            category.custom_fields[DiscourseSolved::ENABLE_ACCEPTED_ANSWERS_CUSTOM_FIELD] = "true"

            configuration_schema[:category_settings]&.each do |field_name, config|
              value = configuration_values.fetch(field_name.to_s, config[:default])
              category.custom_fields[field_name.to_s] = value
            end
            category.save_custom_fields
            DiscourseSolved::AcceptedAnswerCache.reset_accepted_answer_cache
          end

          def configuration_schema
            {
              site_settings: {
                show_filter_by_solved_status: true,
                notify_on_staff_accept_solved: true,
                empty_box_on_unsolved: true,
              },
              category_custom_fields: {
                solved_topics_auto_close_hours: {
                  default: 48,
                  type: :integer,
                  label:
                    I18n.t("discourse_solved.category_type.solved_topics_auto_close_hours.label"),
                  description:
                    I18n.t(
                      "discourse_solved.category_type.solved_topics_auto_close_hours.description",
                    ),
                },
              },
              # TODO (martin) Maybe more things from plugins need to move into this dedicated model?
              # For now we do need a distinction between the two, not sure if this will be used at all yet.
              category_settings: {
              },
            }
          end

          def icon
            "square-check"
          end
        end
      end
    end
  end
end
