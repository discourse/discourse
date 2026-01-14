# frozen_string_literal: true

module DiscourseReactions
  # TODO (martin) Remove this once we have rolled out reactions like sync more widely.
  class MigrationReport
    def self.run(previous_report_data: {}, print_report: true)
      report_data = {
        topic_user_liked: TopicUser.where(liked: true).count,
        user_actions_liked: UserAction.where(action_type: UserAction::LIKE).count,
        user_actions_was_liked: UserAction.where(action_type: UserAction::WAS_LIKED).count,
        post_action_likes:
          PostAction.where(post_action_type_id: PostActionType::LIKE_POST_ACTION_ID).count,
        post_like_count_total: Post.sum(:like_count),
        topic_like_count_total: Topic.sum(:like_count),
        user_stat_likes_given_total: UserStat.sum(:likes_given),
        user_stat_likes_received_total: UserStat.sum(:likes_received),
        given_daily_like_total: GivenDailyLike.sum(:likes_given),
        badge_count: UserBadge.count,
        reactions_total: DiscourseReactions::ReactionUser.count,
      }

      puts humanized_report_data(report_data, previous_report_data) if print_report

      report_data
    end

    def self.generate_diff(report_data, previous_report_data)
      report_data_diff_indicators = {}

      previous_report_data.each do |key, value|
        diff_indicator =
          if report_data[key] < value
            " (-#{value - report_data[key]})"
          elsif report_data[key] > value
            " (+#{report_data[key] - value})"
          else
            " (no change)"
          end

        report_data_diff_indicators[key] = diff_indicator
      end

      report_data_diff_indicators
    end

    def self.humanized_report_data(report_data, previous_report_data = {})
      report_data_diff_indicators = generate_diff(report_data, previous_report_data)

      report_data_reactions_breakdown = {}
      SiteSetting
        .discourse_reactions_enabled_reactions
        .split("|")
        .each do |reaction|
          report_data_reactions_breakdown[reaction] = DiscourseReactions::Reaction.where(
            reaction_value: reaction,
          ).sum(:reaction_users_count)
        end

      <<~REPORT
      Reaction migration report:
      ------------------------------------------------------------

      main_reaction_id:                       #{DiscourseReactions::Reaction.main_reaction_id}
      discourse_reactions_like_sync_enabled:  #{SiteSetting.discourse_reactions_like_sync_enabled}
      discourse_reactions_enabled_reactions:  #{SiteSetting.discourse_reactions_enabled_reactions}
      discourse_reactions_excluded_from_like: #{SiteSetting.discourse_reactions_excluded_from_like}

      PostAction likes:        #{report_data[:post_action_likes]}#{report_data_diff_indicators[:post_action_likes]}
      UserActions.liked:       #{report_data[:user_actions_liked]}#{report_data_diff_indicators[:user_actions_liked]}
      UserActions.was_liked:   #{report_data[:user_actions_was_liked]}#{report_data_diff_indicators[:user_actions_was_liked]}
      UserStat.likes_given:    #{report_data[:user_stat_likes_given_total]}#{report_data_diff_indicators[:user_stat_likes_given_total]}
      UserStat.likes_received: #{report_data[:user_stat_likes_received_total]}#{report_data_diff_indicators[:user_stat_likes_received_total]}
      Post.like_count:         #{report_data[:post_like_count_total]}#{report_data_diff_indicators[:post_like_count_total]}
      Topic.like_count:        #{report_data[:topic_like_count_total]}#{report_data_diff_indicators[:topic_like_count_total]}
      TopicUser.liked:         #{report_data[:topic_user_liked]}#{report_data_diff_indicators[:topic_user_liked]}
      Badge count:             #{report_data[:badge_count]}#{report_data_diff_indicators[:badge_count]}
      Given daily like total:  #{report_data[:given_daily_like_total]}#{report_data_diff_indicators[:given_daily_like_total]}
      Reactions:               #{report_data[:reactions_total]}#{report_data_diff_indicators[:reactions_total]}
      #{
        report_data_reactions_breakdown
          .map { |reaction, count| " -> #{reaction}: #{count}" }
          .join("\n")
      }

      REPORT
    end
  end
end
