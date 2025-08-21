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

        plugin.on(:post_edited) do |post, topic_changed, revisor|
          if DiscourseAi::Translation.enabled?
            grace = [SiteSetting.editing_grace_period.seconds, 5.minutes].max

            if topic_changed
              if revisor.topic_title_changed?
                Jobs.enqueue_in(grace, :detect_translate_topic, topic_id: post.topic_id)
              end
            else
              if revisor.should_create_new_version?
                Jobs.enqueue_in(grace, :detect_translate_post, post_id: post.id)
              end
            end
          end
        end
      end
    end
  end
end
