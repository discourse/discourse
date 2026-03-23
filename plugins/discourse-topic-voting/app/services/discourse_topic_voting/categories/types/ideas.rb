# frozen_string_literal: true

module DiscourseTopicVoting
  module Categories
    module Types
      class Ideas < ::Categories::Types::Base
        type_id :ideas

        class << self
          def visible?
            SiteSetting.enable_ideas_category_type_setup
          end

          def enable_plugin
            SiteSetting.topic_voting_enabled = true
          end

          def category_matches?(category)
            Category.can_vote?(category.id)
          end

          def find_matches
            Category.where(id: DiscourseTopicVoting::CategorySetting.select(:category_id))
          end

          def configure_category(category, guardian:, configuration_values: {})
            category.discourse_topic_voting_category_setting ||=
              DiscourseTopicVoting::CategorySetting.new(category: category)
            category.discourse_topic_voting_category_setting.save!
            Category.reset_voting_cache
          end

          def configuration_schema
            {
              general_category_settings: {
                name: {
                  default: I18n.t("category_types.ideas.name"),
                  type: :string,
                },
                style_type: {
                  default: "emoji",
                  type: :string,
                },
                emoji: {
                  default: "bulb",
                  type: :string,
                },
              },
              site_settings: {
                topic_voting_show_who_voted: true,
                topic_voting_show_votes_on_profile: true,
                topic_voting_tl0_vote_limit: 2,
                topic_voting_tl1_vote_limit: 4,
                topic_voting_tl2_vote_limit: 6,
                topic_voting_tl3_vote_limit: 8,
                topic_voting_tl4_vote_limit: 10,
                topic_voting_alert_votes_left: 1,
              },
            }
          end

          def icon
            "bulb"
          end
        end
      end
    end
  end
end
