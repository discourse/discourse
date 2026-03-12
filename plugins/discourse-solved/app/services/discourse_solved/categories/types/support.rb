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
            category.enable_accepted_answers?
          end

          def find_matches
            Category
              .joins(:_custom_fields)
              .where(
                "category_custom_fields.name = ?",
                DiscourseSolved::ENABLE_ACCEPTED_ANSWERS_CUSTOM_FIELD,
              )
              .where("category_custom_fields.value = ?", "true")
          end

          def configure_category(category, guardian:, configuration_values: {})
            configuration_values.reverse_merge!(
              DiscourseSolved::NOTIFY_ON_STAFF_ACCEPT_SOLVED_CUSTOM_FIELD => "true",
              DiscourseSolved::EMPTY_BOX_ON_UNSOLVED_CUSTOM_FIELD => "true",
            )
            configuration_values.merge!(
              DiscourseSolved::ENABLE_ACCEPTED_ANSWERS_CUSTOM_FIELD => "true",
            )
            configure_custom_fields(category, guardian:, configuration_values:)

            # NOTE (martin) In future we may want to handle category_settings
            # here.
            #
            # Maybe more things from plugins need to move into this dedicated
            # model, but for now we do need a distinction between this and category
            # custom fields, not sure if this will be used at all yet.

            DiscourseSolved::AcceptedAnswerCache.reset_accepted_answer_cache
          end

          def configuration_schema
            {
              general_category_settings: {
                name: {
                  default: I18n.t("category_types.support.name"),
                  type: :string,
                },
                style_type: {
                  default: "emoji",
                  type: :string,
                },
                emoji: {
                  default: "red_question_mark",
                  type: :string,
                },
              },
              site_settings: {
                show_filter_by_solved_status: true,
              },
              category_custom_fields: {
                DiscourseSolved::ENABLE_ACCEPTED_ANSWERS_CUSTOM_FIELD => {
                  default: true,
                  type: :bool,
                  label: I18n.t("discourse_solved.category_type.allow_accepted_answers.label"),
                  required: true,
                  show_on_create: false,
                },
                :solved_topics_auto_close_hours => {
                  default: 48,
                  type: :integer,
                  subtype: :duration,
                  label:
                    I18n.t(
                      "discourse_solved.category_type.solved_topics_auto_close_duration.label",
                    ),
                  description:
                    I18n.t(
                      "discourse_solved.category_type.solved_topics_auto_close_duration.description",
                    ),
                },
                DiscourseSolved::NOTIFY_ON_STAFF_ACCEPT_SOLVED_CUSTOM_FIELD => {
                  default: true,
                  type: :bool,
                  label:
                    I18n.t("discourse_solved.category_type.notify_on_staff_accept_solved.label"),
                },
                DiscourseSolved::EMPTY_BOX_ON_UNSOLVED_CUSTOM_FIELD => {
                  default: true,
                  type: :bool,
                  label: I18n.t("discourse_solved.category_type.empty_box_on_unsolved.label"),
                },
              },
            }
          end

          def icon
            "person_raising_hand"
          end
        end
      end
    end
  end
end
