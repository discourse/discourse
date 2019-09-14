# frozen_string_literal: true

module Jobs
  module DiscourseNarrativeBot
    class GrantBadges < ::Jobs::Onceoff
      def execute_onceoff(args)
        new_user_track_badge = Badge.find_by(
          name: ::DiscourseNarrativeBot::NewUserNarrative::BADGE_NAME
        )

        advanced_user_track_badge = Badge.find_by(
          name: ::DiscourseNarrativeBot::AdvancedUserNarrative::BADGE_NAME
        )

        PluginStoreRow.where(
          plugin_name: ::DiscourseNarrativeBot::PLUGIN_NAME,
          type_name: 'JSON'
        ).find_each do |row|

          value = JSON.parse(row.value)
          completed = value["completed"]
          user = User.find_by(id: row.key)

          if user && completed
            if completed.include?(::DiscourseNarrativeBot::NewUserNarrative.to_s)
              BadgeGranter.grant(new_user_track_badge, user)
            end

            if completed.include?(::DiscourseNarrativeBot::AdvancedUserNarrative.to_s)
              BadgeGranter.grant(advanced_user_track_badge, user)
            end
          end
        end
      end
    end
  end
end
