# frozen_string_literal: true

class DiscourseSolved::UnacceptAnswer
  include Service::Base

  params do
    attribute :post_id, :integer

    validates :post_id, presence: true
  end

  model :post
  model :topic

  only_if(:is_accepted_answer) do
    lock(:topic) { transaction { step :unaccept } }

    step :enqueue_web_hooks
    step :publish_unaccepted
  end

  private

  def fetch_post(params:)
    Post.with_deleted.find_by(id: params.post_id)
  end

  def fetch_topic(post:)
    post.topic || Topic.unscoped.find_by(id: post.topic_id)
  end

  def is_accepted_answer(topic:, post:)
    topic.solved.present? && topic.solved.answer_post_id == post.id
  end

  def unaccept(post:, topic:)
    solved = topic.solved

    UserAction.where(action_type: UserAction::SOLVED, target_post_id: post.id).destroy_all
    Notification.find_by(
      notification_type: Notification.types[:custom],
      user_id: post.user_id,
      topic_id: post.topic_id,
      post_number: post.post_number,
    )&.destroy!
    solved.destroy!
  end

  def enqueue_web_hooks(post:)
    if WebHook.active_web_hooks(:unaccepted_solution).exists?
      payload = WebHook.generate_payload(:post, post)
      WebHook.enqueue_solved_hooks(:unaccepted_solution, post, payload)
    end
  end

  def publish_unaccepted(post:, topic:)
    DiscourseEvent.trigger(:unaccepted_solution, post)
    secure_audience = topic.secure_audience_publish_messages
    MessageBus.publish("/topic/#{topic.id}", { type: :unaccepted_solution }, secure_audience)
  end
end
