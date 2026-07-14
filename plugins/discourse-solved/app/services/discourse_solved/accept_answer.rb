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
  policy :answer_is_acceptable

  lock(:topic) do
    transaction do
      only_if(:should_revoke_previous) { step :revoke_previous_accepted_answer }
      step :credit_post_author
      model :solved_topic, :find_or_create_solved_topic
      model :topic_answer, :create_topic_answer
      only_if(:should_notify_post_author) { step :notify_post_author }
      only_if(:should_notify_topic_owner) { step :notify_topic_owner }
      model :topic_user_ids, optional: true
      only_if(:has_topic_users?) do
        model :screener
        step :notify_tracking_and_watching_users
      end
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

  def should_revoke_previous(topic:)
    topic.reload
    !SiteSetting.solved_allow_multiple_solutions && topic.topic_answers&.any?
  end

  def revoke_previous_accepted_answer(topic:)
    topic_answers = topic.topic_answers

    if topic_answers.any?
      post_ids = topic_answers.pluck(:answer_post_id)
      UserAction.where(action_type: UserAction::SOLVED, target_post_id: post_ids).destroy_all
    end

    topic.solved.destroy!
  end

  def credit_post_author(post:, guardian:)
    UserAction.log_action!(
      action_type: UserAction::SOLVED,
      user_id: post.user_id,
      acting_user_id: guardian.user.id,
      target_post_id: post.id,
      target_topic_id: post.topic_id,
    )
  end

  def should_notify_post_author(post:, guardian:)
    return if guardian.user.id == post.user_id || !User.exists?(post.user_id)
    return if !UserOption.exists?(user_id: post.user_id, notify_on_solved: true)
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
    return if !topic.category&.notify_on_staff_accept_solved?
    return if guardian.user.id == topic.user_id || !User.exists?(topic.user_id)
    return if !UserOption.exists?(user_id: topic.user_id, notify_on_solved: true)
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

  def has_topic_users?(topic_user_ids:)
    topic_user_ids.present?
  end

  def fetch_topic_user_ids(post:, topic:, guardian:)
    already_notified_ids = [guardian.user.id, post.user_id, topic.user_id]

    TopicUser
      .where(topic:)
      .where("notification_level >= ?", TopicUser.notification_levels[:tracking])
      .where.not(user_id: already_notified_ids)
      .joins(user: :user_option)
      .where(user_options: { notify_on_solved: true })
      .pluck(:user_id)
  end

  def fetch_screener(guardian:, topic_user_ids:)
    UserCommScreener.new(acting_user_id: guardian.user.id, target_user_ids: topic_user_ids)
  end

  def notify_tracking_and_watching_users(post:, topic:, guardian:, topic_user_ids:, screener:)
    notification_data = {
      message: "solved.topic_solved_notification",
      display_username: guardian.user.username,
      topic_title: topic.title,
      title: "solved.notification.topic_solved_title",
    }.to_json

    records =
      topic_user_ids.filter_map do |user_id|
        next if screener.ignoring_or_muting_actor?(user_id)

        {
          notification_type: Notification.types[:custom],
          user_id: user_id,
          topic_id: topic.id,
          post_number: post.post_number,
          data: notification_data,
        }
      end

    Notification::Action::BulkCreate.call(records:)
  end

  def topic_will_auto_close(solved_topic:)
    solved_topic.previously_new_record? && solved_topic.topic_timer.present?
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

  def publish_solution(post:, topic:, guardian:)
    DiscourseEvent.trigger(:accepted_solution, post)
    MessageBus.publish(
      "/topic/#{topic.id}",
      {
        type: :accepted_solution,
        accepted_answers: DiscourseSolved::AcceptedAnswersHelper.serialize(topic.reload, guardian),
      },
      topic.secure_audience_publish_messages,
    )
  end

  def answer_is_acceptable(topic:, post:)
    !topic.topic_answers.exists?(answer_post_id: post.id)
  end

  def find_or_create_solved_topic(topic:)
    DiscourseSolved::SolvedTopic.find_or_create_by!(topic:)
  end

  def create_topic_answer(solved_topic:, post:, guardian:)
    DiscourseSolved::TopicAnswer.create!(solved_topic:, post:, accepter: guardian.user)
  end
end
