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
            return false if !SiteSetting.topic_voting_enabled

            DiscourseTopicVoting::CategorySetting.exists?(category_id: category.id)
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

          def unconfigure_category(category, guardian:)
            category.discourse_topic_voting_category_setting.destroy!
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
                topic_voting_show_who_voted: {
                  default: true,
                  label: I18n.t("topic_voting.category_type.show_who_voted.label"),
                },
                topic_voting_show_votes_on_profile: {
                  default: true,
                  label: I18n.t("topic_voting.category_type.show_votes_on_profile.label"),
                },
                topic_voting_enable_vote_limits: {
                  default: true,
                  label: I18n.t("topic_voting.category_type.enable_vote_limits.label"),
                },
                topic_voting_tl0_vote_limit: {
                  default: 2,
                  label: I18n.t("topic_voting.category_type.tl0_vote_limit.label"),
                },
                topic_voting_tl1_vote_limit: {
                  default: 4,
                  label: I18n.t("topic_voting.category_type.tl1_vote_limit.label"),
                },
                topic_voting_tl2_vote_limit: {
                  default: 6,
                  label: I18n.t("topic_voting.category_type.tl2_vote_limit.label"),
                },
                topic_voting_tl3_vote_limit: {
                  default: 8,
                  label: I18n.t("topic_voting.category_type.tl3_vote_limit.label"),
                },
                topic_voting_tl4_vote_limit: {
                  default: 10,
                  label: I18n.t("topic_voting.category_type.tl4_vote_limit.label"),
                },
                topic_voting_alert_votes_left: {
                  default: 1,
                  label: I18n.t("topic_voting.category_type.alert_votes_left.label"),
                },
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
