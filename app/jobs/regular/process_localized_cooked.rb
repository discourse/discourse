# frozen_string_literal: true

module Jobs
  class ProcessLocalizedCooked < ::Jobs::Base
    def execute(args)
      DistributedMutex.synchronize(
        "process_localized_cook_#{args[:post_localization_id]}",
        validity: 10.minutes,
      ) do
        post_localization = PostLocalization.find_by(id: args[:post_localization_id])
        return if post_localization.blank?

        post = post_localization.post
        return if post.blank? || post.topic.blank?

        processor = LocalizedCookedPostProcessor.new(post_localization, post, {})
        processor.post_process
        cooked = processor.html.strip

        post_localization.update_column(:cooked, cooked) if cooked.present?

        if post.is_first_post?
          topic_localization = post.topic.localizations.find_by(locale: post_localization.locale)
          topic_localization.update_excerpt(cooked:) if topic_localization
        end

        MessageBus.publish("/topic/#{post.topic_id}", type: :localized, id: post.id)
      end
    end
  end
end
