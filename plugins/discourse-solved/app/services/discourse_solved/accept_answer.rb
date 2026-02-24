# frozen_string_literal: true

class DiscourseSolved::AcceptAnswer
  include Service::Base

  params do
    attribute :post_id, :integer

    validates :post_id, presence: true
  end

  model :post
  model :topic
  policy :can_accept_answer

  lock(:topic) do
    transaction do
      only_if(:previous_answer_exists) { step :remove_previous_accepted_answer }
      step :log_user_action
      model :solved, :create_solved
      only_if(:should_notify_post_author) { step :notify_post_author }
      only_if(:should_notify_topic_owner) { step :notify_topic_owner }
    end
  end

  only_if(:accepted_solution_webhooks_active) { step :enqueue_web_hooks }
  only_if(:topic_will_auto_close) { step :publish_topic_reload }
  step :publish_solution

  private

  def fetch_post(params:)
    Post.find_by(id: params.post_id)
  end

  def fetch_topic(post:, guardian:)
    return Topic.with_deleted.find_by(id: post.topic_id) if guardian.is_staff?
    post.topic
  end

  def can_accept_answer(guardian:, topic:, post:)
    guardian.can_accept_answer?(topic, post)
  end

  def previous_answer_exists(topic:)
    topic.solved&.answer_post_id.present?
  end

  def remove_previous_accepted_answer(topic:)
    UserAction.where(
      action_type: UserAction::SOLVED,
      target_post: topic.solved.answer_post,
    ).destroy_all
    topic.solved.destroy!
  end

  def log_user_action(post:, guardian:)
    UserAction.log_action!(
      action_type: UserAction::SOLVED,
      user_id: post.user_id,
      acting_user_id: guardian.user.id,
      target_post_id: post.id,
      target_topic_id: post.topic_id,
    )
  end

  def create_solved(post:, topic:, guardian:)
    DiscourseSolved::SolvedTopic.create(topic:, answer_post: post, accepter: guardian.user)
  end

  def should_notify_post_author(post:, guardian:)
    return if guardian.user.id == post.user_id
    screener = UserCommScreener.new(acting_user_id: guardian.user.id, target_user_ids: post.user_id)
    !screener.ignoring_or_muting_actor?(post.user_id)
  end

  def notify_post_author(post:, topic:, guardian:)
    Notification.create!(
      notification_type: Notification.types[:custom],
      user_id: post.user_id,
      topic_id: post.topic_id,
      post_number: post.post_number,
      data: {
        message: "solved.accepted_notification",
        display_username: guardian.user.username,
        topic_title: topic.title,
        title: "solved.notification.title",
      }.to_json,
    )
  end

  def should_notify_topic_owner(topic:, guardian:)
    return unless SiteSetting.notify_on_staff_accept_solved
    return if guardian.user.id == topic.user_id
    screener =
      UserCommScreener.new(acting_user_id: guardian.user.id, target_user_ids: topic.user_id)
    !screener.ignoring_or_muting_actor?(topic.user_id)
  end

  def notify_topic_owner(post:, topic:, guardian:)
    Notification.create!(
      notification_type: Notification.types[:custom],
      user_id: topic.user_id,
      topic_id: post.topic_id,
      post_number: post.post_number,
      data: {
        message: "solved.accepted_notification",
        display_username: guardian.user.username,
        topic_title: topic.title,
        title: "solved.notification.title",
      }.to_json,
    )
  end

  def topic_will_auto_close(solved:)
    solved.topic_timer.present?
  end

  def publish_topic_reload(topic:)
    MessageBus.publish(
      "/topic/#{topic.id}",
      { reload_topic: true },
      topic.secure_audience_publish_messages,
    )
  end

  def accepted_solution_webhooks_active
    WebHook.active_web_hooks(:accepted_solution).exists?
  end

  def enqueue_web_hooks(post:)
    WebHook.enqueue_solved_hooks(:accepted_solution, post, WebHook.generate_payload(:post, post))
  end

  def publish_solution(post:, topic:)
    DiscourseEvent.trigger(:accepted_solution, post)
    MessageBus.publish(
      "/topic/#{topic.id}",
      { type: :accepted_solution, accepted_answer: topic.reload.accepted_answer_post_info },
      topic.secure_audience_publish_messages,
    )
  end
end
