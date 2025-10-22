# frozen_string_literal: true

class ComposerMessagesFinder
  def initialize(user, details)
    @user = user
    @details = details
    @topic = Topic.find_by(id: details[:topic_id]) if details[:topic_id]
  end

  def self.check_methods
    @check_methods ||= instance_methods.find_all { |m| m =~ /\Acheck\_/ }
  end

  def find
    return if editing_post?

    self.class.check_methods.each do |m|
      msg = public_send(m)
      return msg if msg.present?
    end

    nil
  end

  # Determines whether to show the user education text
  def check_education_message
    return if @topic&.private_message?

    education_key = creating_topic? ? "education.new-topic" : "education.new-reply"
    count = @user.topic_count + @user.post_count

    if count < SiteSetting.educate_until_posts
      return(
        {
          id: "education",
          templateName: "education",
          wait_for_typing: true,
          body:
            PrettyText.cook(
              I18n.t(
                education_key,
                education_posts_text:
                  I18n.t("education.until_posts", count: SiteSetting.educate_until_posts),
                site_name: SiteSetting.title,
                base_path: Discourse.base_path,
              ),
            ),
        }
      )
    end

    nil
  end

  # New users have a limited number of replies in a topic
  def check_new_user_many_replies
    return unless replying? && @user.posted_too_much_in_topic?(@details[:topic_id])

    {
      id: "too_many_replies",
      templateName: "education",
      body:
        PrettyText.cook(
          I18n.t(
            "education.too_many_replies",
            newuser_max_replies_per_topic: SiteSetting.newuser_max_replies_per_topic,
          ),
        ),
    }
  end

  def check_dominating_topic
    return unless educate_reply?(:notified_about_dominating_topic)

    if @topic.blank? || @topic.user_id == @user.id ||
         @topic.posts_count < SiteSetting.summary_posts_required || @topic.private_message?
      return
    end

    posts_by_user = @user.posts.where(topic_id: @topic.id).count

    ratio = (posts_by_user.to_f / @topic.posts_count.to_f)
    return if ratio < (SiteSetting.dominating_topic_minimum_percent.to_f / 100.0)

    # Log the topic notification
    UserHistory.create!(
      action: UserHistory.actions[:notified_about_dominating_topic],
      target_user_id: @user.id,
      topic_id: @details[:topic_id],
    )

    {
      id: "dominating_topic",
      templateName: "dominating-topic",
      wait_for_typing: true,
      extraClass: "education-message dominating-topic-message",
      body: PrettyText.cook(I18n.t("education.dominating_topic")),
    }
  end

  def check_get_a_room(min_users_posted: 5)
    return unless @user.guardian.can_send_private_messages?
    return unless educate_reply?(:notified_about_get_a_room)
    return if @details[:post_id].blank?
    return if @topic.category&.read_restricted

    reply_to_user_id = Post.where(id: @details[:post_id]).pluck(:user_id)[0]

    # Users's last x posts in the topic
    last_x_replies =
      @topic
        .posts
        .where(user_id: @user.id)
        .order("created_at desc")
        .limit(SiteSetting.get_a_room_threshold)
        .pluck(:reply_to_user_id)
        .find_all { |uid| uid != @user.id && uid == reply_to_user_id }

    return if last_x_replies.size != SiteSetting.get_a_room_threshold
    return if @topic.posts.count("distinct user_id") < min_users_posted

    UserHistory.create!(
      action: UserHistory.actions[:notified_about_get_a_room],
      target_user_id: @user.id,
      topic_id: @details[:topic_id],
    )

    reply_username = User.where(id: last_x_replies[0]).pick(:username)

    {
      id: "get_a_room",
      templateName: "get-a-room",
      wait_for_typing: true,
      reply_username: reply_username,
      extraClass: "education-message get-a-room",
      body:
        PrettyText.cook(
          I18n.t(
            "education.get_a_room",
            count: SiteSetting.get_a_room_threshold,
            reply_username: reply_username,
            base_path: Discourse.base_path,
          ),
        ),
    }
  end

  def check_dont_feed_the_trolls
    return if !replying?

    post =
      if @details[:post_id]
        Post.find_by(id: @details[:post_id])
      else
        @topic&.first_post
      end

    return if post.blank?

    flags = post.flags.active.group(:user_id).count
    flagged_by_replier = flags[@user.id].to_i > 0
    flagged_by_others = flags.values.sum >= SiteSetting.dont_feed_the_trolls_threshold

    return if !flagged_by_replier && !flagged_by_others

    {
      id: "dont_feed_the_trolls",
      templateName: "education",
      wait_for_typing: false,
      extraClass: "urgent",
      body: PrettyText.cook(I18n.t("education.dont_feed_the_trolls")),
    }
  end

  def self.user_not_seen_in_a_while(usernames)
    User
      .where(username_lower: usernames)
      .where("last_seen_at < ?", SiteSetting.pm_warn_user_last_seen_months_ago.months.ago)
      .pluck(:username)
      .sort
  end

  private

  def educate_reply?(type)
    replying? && @details[:topic_id] && (@topic.present? && !@topic.private_message?) &&
      (@user.post_count >= SiteSetting.educate_until_posts) &&
      !UserHistory.exists_for_user?(@user, type, topic_id: @details[:topic_id])
  end

  def creating_topic?
    @details[:composer_action] == "createTopic"
  end

  def replying?
    @details[:composer_action] == "reply"
  end

  def editing_post?
    @details[:composer_action] == "edit"
  end
end
