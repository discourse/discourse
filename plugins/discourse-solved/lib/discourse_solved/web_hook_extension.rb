# frozen_string_literal: true

module DiscourseSolved::WebHookExtension
  extend ActiveSupport::Concern

  class_methods do
    def enqueue_solved_hooks(event, post, payload = nil)
      if active_web_hooks(event).exists? && post.present?
        payload ||= WebHook.generate_payload(:post, post)

        WebHook.enqueue_hooks(
          :solved,
          event,
          id: post.id,
          category_id: post.topic&.category_id,
          tag_ids: post.topic&.tags&.pluck(:id),
          payload: payload,
        )
      end
    end
  end
end
