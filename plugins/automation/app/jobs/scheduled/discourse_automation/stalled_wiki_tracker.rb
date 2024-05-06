# frozen_string_literal: true

module Jobs
  class DiscourseAutomation::StalledWikiTracker < ::Jobs::Scheduled
    every 10.minutes

    def execute(_args = nil)
      name = ::DiscourseAutomation::Triggers::STALLED_WIKI

      ::DiscourseAutomation::Automation
        .where(trigger: name, enabled: true)
        .find_each do |automation|
          stalled_after = automation.trigger_field("stalled_after")
          stalled_duration = ISO8601::Duration.new(stalled_after["value"]).to_seconds
          finder = Post.where("wiki = TRUE AND last_version_at <= ?", stalled_duration.seconds.ago)

          restricted_category = automation.trigger_field("restricted_category")
          if restricted_category["value"]
            finder =
              finder.joins(:topic).where("topics.category_id = ?", restricted_category["value"])
          end

          finder.each do |post|
            last_trigger_date = post.custom_fields["stalled_wiki_triggered_at"]
            if last_trigger_date
              retriggered_after = automation.trigger_field("retriggered_after")
              retrigger_duration = ISO8601::Duration.new(retriggered_after["value"]).to_seconds

              next if Time.parse(last_trigger_date) + retrigger_duration >= Time.zone.now
            end

            post.upsert_custom_fields(stalled_wiki_triggered_at: Time.zone.now)
            run_trigger(automation, post)
          end
        end
    end

    def run_trigger(automation, post)
      user_ids =
        (
          post.post_revisions.order("post_revisions.created_at DESC").limit(5).pluck(:user_id) +
            [post.user_id]
        ).compact.uniq

      automation.trigger!(
        "kind" => ::DiscourseAutomation::Triggers::STALLED_WIKI,
        "post" => post,
        "topic" => post.topic,
        "usernames" => User.where(id: user_ids).pluck(:username),
        "placeholders" => {
          "wiki_url" => Discourse.base_url + post.url,
        },
      )
    end
  end
end
