# frozen_string_literal: true

class DiscourseSolved::AcceptAnswer
  include Service::Base

  params do
    attribute :post_id, :integer
    validates :post_id, presence: true
  end

  model :post
  model :topic

  transaction do
    step :accept
    step :notify_post_author
    step :notify_topic_owner
  end

  step :enqueue_web_hooks
  step :publish_solution

  MAX_AUTO_CLOSE_HOURS = 20.years.to_i / 1.hour.to_i

  private

  def fetch_post(params:)
    Post.find_by(id: params.post_id)
  end

  def fetch_topic(post:)
    post.topic || Topic.with_deleted.find_by(id: post.topic_id)
  end

  def accept(post:, topic:, guardian:)
    acting_user = guardian.user

    DistributedMutex.synchronize("discourse_solved_toggle_answer_#{topic.id}") do
      solved = topic.solved

      if previous_accepted_post_id = solved&.answer_post_id
        UserAction.where(
          action_type: UserAction::SOLVED,
          target_post_id: previous_accepted_post_id,
        ).destroy_all
        solved.destroy!
      else
        UserAction.log_action!(
          action_type: UserAction::SOLVED,
          user_id: post.user_id,
          acting_user_id: acting_user.id,
          target_post_id: post.id,
          target_topic_id: post.topic_id,
        )
      end

      solved = DiscourseSolved::SolvedTopic.new(topic:, answer_post: post, accepter: acting_user)

      auto_close_hours = 0
      if topic&.category.present?
        auto_close_hours = topic.category.custom_fields["solved_topics_auto_close_hours"].to_i
        auto_close_hours = MAX_AUTO_CLOSE_HOURS if auto_close_hours > MAX_AUTO_CLOSE_HOURS
      end

      auto_close_hours = SiteSetting.solved_topics_auto_close_hours if auto_close_hours == 0

      if (auto_close_hours > 0) && !topic.closed
        topic_timer =
          topic.set_or_create_timer(
            TopicTimer.types[:silent_close],
            nil,
            based_on_last_post: true,
            duration_minutes: auto_close_hours * 60,
          )
        solved.topic_timer = topic_timer

        MessageBus.publish(
          "/topic/#{topic.id}",
          { reload_topic: true },
          topic.secure_audience_publish_messages,
        )
      end

      solved.save!
    end

    context[:accepted_answer] = topic.reload.accepted_answer_post_info
  end

  def notify_post_author(post:, topic:, guardian:)
    acting_user = guardian.user
    return if acting_user.id == post.user_id
    return unless notify_allowed?(recipient: post.user, user: acting_user)

    Notification.create!(
      notification_type: Notification.types[:custom],
      user_id: post.user_id,
      topic_id: post.topic_id,
      post_number: post.post_number,
      data: {
        message: "solved.accepted_notification",
        display_username: acting_user.username,
        topic_title: topic.title,
        title: "solved.notification.title",
      }.to_json,
    )
  end

  def notify_topic_owner(post:, topic:, guardian:)
    acting_user = guardian.user
    return unless SiteSetting.notify_on_staff_accept_solved
    return if acting_user.id == topic.user_id
    return unless notify_allowed?(recipient: topic.user, user: acting_user)

    Notification.create!(
      notification_type: Notification.types[:custom],
      user_id: topic.user_id,
      topic_id: post.topic_id,
      post_number: post.post_number,
      data: {
        message: "solved.accepted_notification",
        display_username: acting_user.username,
        topic_title: topic.title,
        title: "solved.notification.title",
      }.to_json,
    )
  end

  def notify_allowed?(recipient:, user:)
    !UserCommScreener.new(
      acting_user_id: user.id,
      target_user_ids: recipient.id,
    ).ignoring_or_muting_actor?(recipient.id)
  end

  def enqueue_web_hooks(post:)
    if WebHook.active_web_hooks(:accepted_solution).exists?
      payload = WebHook.generate_payload(:post, post)
      WebHook.enqueue_solved_hooks(:accepted_solution, post, payload)
    end
  end

  def publish_solution(post:, topic:, accepted_answer:)
    DiscourseEvent.trigger(:accepted_solution, post)

    secure_audience = topic.secure_audience_publish_messages
    MessageBus.publish(
      "/topic/#{topic.id}",
      { type: :accepted_solution, accepted_answer: },
      secure_audience,
    )
  end
end
