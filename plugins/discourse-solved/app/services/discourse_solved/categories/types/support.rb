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

          def plugin_enabled?
            SiteSetting.solved_enabled
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
              DiscourseSolved::SHARED_ISSUES_ENABLED_CUSTOM_FIELD => "true",
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

          def unconfigure_category(category, guardian:)
            category.custom_fields[DiscourseSolved::ENABLE_ACCEPTED_ANSWERS_CUSTOM_FIELD] = "false"
            category.save!

            DiscourseSolved::AcceptedAnswerCache.reset_accepted_answer_cache
          end

          def configuration_schema
            schema = {
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
                prioritize_solved_topics_in_search: false,
                show_who_marked_solved: false,
              },
              category_custom_fields: {
                DiscourseSolved::ENABLE_ACCEPTED_ANSWERS_CUSTOM_FIELD => {
                  default: true,
                  type: :bool,
                  label: I18n.t("discourse_solved.category_type.allow_accepted_answers.label"),
                  required: true,
                  show_on_create: false,
                  show_on_edit: false,
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
              },
              site_texts: {
              },
            }

            # The empty-box-on-unsolved styling isn't used by the Horizon theme,
            # so hide the toggle (and the field) when Horizon is the site's
            # default theme.
            unless default_theme_horizon?
              schema[:category_custom_fields][
                DiscourseSolved::EMPTY_BOX_ON_UNSOLVED_CUSTOM_FIELD
              ] = {
                default: true,
                type: :bool,
                label: I18n.t("discourse_solved.category_type.empty_box_on_unsolved.label"),
              }
            end

            if SiteSetting.enable_solved_shared_issues
              schema[:category_custom_fields][
                DiscourseSolved::SHARED_ISSUES_ENABLED_CUSTOM_FIELD
              ] = {
                default: true,
                type: :bool,
                label: I18n.t("discourse_solved.category_type.enable_shared_issues.label"),
                description:
                  I18n.t("discourse_solved.category_type.enable_shared_issues.description"),
              }

              schema[:site_texts]["js.solved.shared_issue.label"] = {
                label: I18n.t("discourse_solved.category_type.shared_issue_label.label"),
                description:
                  I18n.t("discourse_solved.category_type.shared_issue_label.description"),
                depends_on: DiscourseSolved::SHARED_ISSUES_ENABLED_CUSTOM_FIELD,
              }
            end

            schema
          end

          def icon
            "person_raising_hand"
          end

          private

          def default_theme_horizon?
            SiteSetting.default_theme_id == Theme.horizon_theme.id
          end
        end
      end
    end
  end
end
