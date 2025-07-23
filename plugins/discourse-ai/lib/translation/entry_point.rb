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

        plugin.on(:post_edited) do |post, topic_changed|
          if DiscourseAi::Translation.enabled? && topic_changed
            Jobs.enqueue(:detect_translate_topic, topic_id: post.topic_id)
          end
        end
      end
    end
  end
end
