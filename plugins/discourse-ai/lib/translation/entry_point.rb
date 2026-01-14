# frozen_string_literal: true

module DiscourseAi
  module Translation
    class EntryPoint
      def inject_into(plugin)
        plugin.on(:post_created) do |post|
          if DiscourseAi::Translation.enabled?
            Jobs.enqueue(:detect_translate_post, post_id: post.id)
          end
        end

        plugin.on(:topic_created) do |topic|
          if DiscourseAi::Translation.enabled?
            Jobs.enqueue(:detect_translate_topic, topic_id: topic.id)
          end
        end

        plugin.on(:post_edited) do |post, _, revisor|
          if DiscourseAi::Translation.enabled?
            grace = [SiteSetting.editing_grace_period.seconds, 5.minutes].max

            title_changed = revisor.topic_title_changed?
            raw_changed = revisor.raw_changed?
            excerpt_changed = post.is_first_post? && raw_changed

            if title_changed || excerpt_changed
              Jobs.enqueue_in(grace, :detect_translate_topic, topic_id: post.topic_id)
            end

            Jobs.enqueue_in(grace, :detect_translate_post, post_id: post.id) if raw_changed
          end
        end
      end
    end
  end
end
