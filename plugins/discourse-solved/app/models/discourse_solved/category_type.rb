# frozen_string_literal: true

module DiscourseSolved
  class CategoryType < Categories::Types::Base
    type_id :support

    class << self
      def enable_plugin
        SiteSetting.solved_enabled = true
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
          category_settings: {
            solved_topics_auto_close_hours: {
              default: 48,
              type: :integer,
              label: I18n.t("discourse_solved.category_type.solved_topics_auto_close_hours.label"),
              description:
                I18n.t("discourse_solved.category_type.solved_topics_auto_close_hours.description"),
            },
          },
        }
      end

      ICON_VARIANTS = %w[
        person_raising_hand:t2
        person_raising_hand:t3
        person_raising_hand:t4
        person_raising_hand:t5
        person_raising_hand:t6
        man_raising_hand:t2
        man_raising_hand:t3
        man_raising_hand:t4
        man_raising_hand:t5
        man_raising_hand:t6
        woman_raising_hand:t2
        woman_raising_hand:t3
        woman_raising_hand:t4
        woman_raising_hand:t5
        woman_raising_hand:t6
      ].freeze

      def icon
        ICON_VARIANTS.sample
      end
    end
  end
end
