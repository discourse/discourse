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

        plugin.on(:category_updated) do |category|
          next unless category.is_a?(Category)

          changed_fields =
            %w[name description].select { |field| category.previous_changes.key?(field) }

          if DiscourseAi::Translation.enabled? && changed_fields.present?
            Jobs.enqueue(
              :localize_categories,
              category_id: category.id,
              fields: changed_fields,
              limit: 1,
              force: true,
            )
          end
        end

        plugin.on(:tag_updated) do |tag|
          next unless tag.is_a?(Tag)

          changed_fields = %w[name description].select { |field| tag.previous_changes.key?(field) }

          if DiscourseAi::Translation.enabled? && changed_fields.present?
            Jobs.enqueue(
              :localize_tags,
              tag_id: tag.id,
              fields: changed_fields,
              limit: 1,
              force: true,
            )
          end
        end

        plugin.on(:site_setting_changed) do |name, _old_value, new_value|
          if name == :ai_translation_enabled && new_value &&
               SiteSetting.ai_translation_backfill_start_date.blank?
            SiteSetting.ai_translation_backfill_start_date = 5.days.ago.utc.to_date.iso8601
          end
        end
      end
    end
  end
end
