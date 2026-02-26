# frozen_string_literal: true

module DiscourseSolved
  class Answer::Accept
    include Service::Base

    params do
      attribute :post_id, :integer

      validates :post_id, presence: true
    end

    model :post
    model :topic
    policy :can_accept_answer

    lock(:topic) do
      model :previous_solution, optional: true

      transaction do
        only_if(:has_previous_solution) { step :revoke_previous_accepted_answer }

        step :log_user_action
        model :solved_topic, :create_solved_topic

        only_if(:should_notify_answer_author) { step :notify_answer_author }

        only_if(:should_notify_topic_author) { step :notify_topic_author }

        only_if(:should_auto_close_topic) { step :schedule_auto_close }
      end

      only_if(:should_auto_close_topic) { step :publish_topic_reload }

      only_if(:has_accepted_solution_webhook) { step :publish_webhook_event }

      step :trigger_accepted_solution_event
      step :publish_solution_update
    end

    private

    def fetch_post(params:)
      Post.find_by(id: params.post_id)
    end

    def fetch_topic(post:, guardian:)
      topic = post.topic
      topic = Topic.with_deleted.find_by(id: post.topic_id) if topic.nil? && guardian.is_staff?
      topic
    end

    def can_accept_answer(guardian:, topic:, post:)
      guardian.can_accept_answer?(topic, post)
    end

    def fetch_previous_solution(topic:)
      topic.solved
    end

    def has_previous_solution(previous_solution:)
      previous_solution.present?
    end

    def revoke_previous_accepted_answer(previous_solution:)
      UserAction.where(
        action_type: UserAction::SOLVED,
        target_post_id: previous_solution.answer_post_id,
      ).destroy_all
      previous_solution.destroy!
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

    def create_solved_topic(topic:, post:, guardian:)
      DiscourseSolved::SolvedTopic.create!(topic:, answer_post: post, accepter: guardian.user)
    end

    def should_notify_answer_author(guardian:, post:)
      return if guardian.user.id == post.user_id
      !UserCommScreener.new(
        acting_user_id: guardian.user.id,
        target_user_ids: post.user_id,
      ).ignoring_or_muting_actor?(post.user_id)
    end

    def notify_answer_author(post:, topic:, guardian:)
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

    def should_notify_topic_author(guardian:, topic:)
      return if !SiteSetting.notify_on_staff_accept_solved
      return if guardian.user.id == topic.user_id
      !UserCommScreener.new(
        acting_user_id: guardian.user.id,
        target_user_ids: topic.user_id,
      ).ignoring_or_muting_actor?(topic.user_id)
    end

    def notify_topic_author(post:, topic:, guardian:)
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

    def should_auto_close_topic(topic:)
      return if topic.closed
      DiscourseSolved::SolvedTopic.auto_close_hours_for(topic) > 0
    end

    def schedule_auto_close(topic:, solved_topic:)
      topic_timer =
        topic.set_or_create_timer(
          TopicTimer.types[:silent_close],
          nil,
          based_on_last_post: true,
          duration_minutes: DiscourseSolved::SolvedTopic.auto_close_hours_for(topic) * 60,
        )
      solved_topic.update!(topic_timer:)
    end

    def publish_topic_reload(topic:)
      MessageBus.publish("/topic/#{topic.id}", reload_topic: true)
    end

    def has_accepted_solution_webhook
      WebHook.active_web_hooks(:accepted_solution).exists?
    end

    def publish_webhook_event(post:)
      payload = WebHook.generate_payload(:post, post)
      WebHook.enqueue_solved_hooks(:accepted_solution, post, payload)
    end

    def trigger_accepted_solution_event(post:)
      DiscourseEvent.trigger(:accepted_solution, post)
    end

    def publish_solution_update(topic:)
      topic.reload
      accepted_answer = topic.accepted_answer_post_info
      message = { type: :accepted_solution, accepted_answer: }

      secure_audience = topic.secure_audience_publish_messages
      if secure_audience[:user_ids] != [] && secure_audience[:group_ids] != []
        MessageBus.publish("/topic/#{topic.id}", message, secure_audience)
      end
    end
  end
end
