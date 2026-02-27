# frozen_string_literal: true

class DiscourseSolved::UnacceptAnswer
  include Service::Base

  params do
    attribute :post_id, :integer

    validates :post_id, presence: true
  end

  model :post
  model :topic
  policy :can_unaccept_answer

  only_if(:post_is_accepted_answer) do
    lock(:topic) do
      transaction do
        step :revoke_solved_credit
        step :remove_accepted_answer_notification
        step :unmark_as_solved
      end
    end

    only_if(:unaccepted_solution_webhooks_active) { step :enqueue_web_hooks }
    step :publish_unaccepted
  end

  private

  def fetch_post(params:, guardian:)
    return Post.with_deleted.find_by(id: params.post_id) if guardian.is_staff?
    Post.find_by(id: params.post_id)
  end

  def fetch_topic(post:, guardian:)
    return Topic.with_deleted.find_by(id: post.topic_id) if guardian.is_staff?
    post.topic
  end

  def can_unaccept_answer(guardian:, topic:, post:)
    guardian.can_unaccept_answer?(topic, post)
  end

  def post_is_accepted_answer(topic:, post:)
    topic.solved&.answer_post == post
  end

  def revoke_solved_credit(post:)
    UserAction.where(action_type: UserAction::SOLVED, target_post: post).destroy_all
  end

  def remove_accepted_answer_notification(post:, topic:)
    Notification.find_by(
      topic:,
      notification_type: Notification.types[:custom],
      user: post.user,
      post_number: post.post_number,
    )&.destroy!
  end

  def unmark_as_solved(topic:)
    topic.solved.destroy!
  end

  def unaccepted_solution_webhooks_active
    WebHook.active_web_hooks(:unaccepted_solution).exists?
  end

  def enqueue_web_hooks(post:)
    WebHook.enqueue_solved_hooks(:unaccepted_solution, post, WebHook.generate_payload(:post, post))
  end

  def publish_unaccepted(post:, topic:)
    DiscourseEvent.trigger(:unaccepted_solution, post)
    MessageBus.publish(
      "/topic/#{topic.id}",
      { type: :unaccepted_solution },
      topic.secure_audience_publish_messages,
    )
  end
end
