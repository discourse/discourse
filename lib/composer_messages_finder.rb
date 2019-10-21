# frozen_string_literal: true

class ComposerMessagesFinder

  def initialize(user, details)
    @user = user
    @details = details
    @topic = Topic.find_by(id: details[:topic_id]) if details[:topic_id]
  end

  def self.check_methods
    @check_methods ||= instance_methods.find_all { |m| m =~ /^check\_/ }
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

    if creating_topic?
      count = @user.created_topic_count
      education_key = 'education.new-topic'
    else
      count = @user.post_count
      education_key = 'education.new-reply'
    end

    if count < SiteSetting.educate_until_posts
      return {
        id: 'education',
        templateName: 'education',
        wait_for_typing: true,
        body: PrettyText.cook(
          I18n.t(
            education_key,
            education_posts_text: I18n.t('education.until_posts', count: SiteSetting.educate_until_posts),
            site_name: SiteSetting.title,
            base_path: Discourse.base_path
          )
        )
      }
    end

    nil
  end

  # New users have a limited number of replies in a topic
  def check_new_user_many_replies
    return unless replying? && @user.posted_too_much_in_topic?(@details[:topic_id])

    {
      id: 'too_many_replies',
      templateName: 'education',
      body: PrettyText.cook(I18n.t('education.too_many_replies', newuser_max_replies_per_topic: SiteSetting.newuser_max_replies_per_topic))
    }
  end

  # Should a user be contacted to update their avatar?
  def check_avatar_notification

    # A user has to be basic at least to be considered for an avatar notification
    return unless @user.has_trust_level?(TrustLevel[1])

    # We don't notify users who have avatars or who have been notified already.
    return if @user.uploaded_avatar_id || UserHistory.exists_for_user?(@user, :notified_about_avatar)

    # Do not notify user if any of the following is true:
    # - "disable avatar education message" is enabled
    # - "sso overrides avatar" is enabled
    # - "allow uploaded avatars" is disabled
    return if SiteSetting.disable_avatar_education_message || SiteSetting.sso_overrides_avatar || !SiteSetting.allow_uploaded_avatars

    # If we got this far, log that we've nagged them about the avatar
    UserHistory.create!(action: UserHistory.actions[:notified_about_avatar], target_user_id: @user.id)

    # Return the message
    {
      id: 'avatar',
      templateName: 'education',
      body: PrettyText.cook(I18n.t('education.avatar', profile_path: "/u/#{@user.username_lower}/preferences/account#profile-picture"))
    }
  end

  # Is a user replying too much in succession?
  def check_sequential_replies
    return unless educate_reply?(:notified_about_sequential_replies)

    # Count the posts made by this user in the last day
    recent_posts_user_ids = Post.where(topic_id: @details[:topic_id])
      .where("created_at > ?", 1.day.ago)
      .where(post_type: Post.types[:regular])
      .order('created_at desc')
      .limit(SiteSetting.sequential_replies_threshold)
      .pluck(:user_id)

    # Did we get back as many posts as we asked for, and are they all by the current user?
    return if recent_posts_user_ids.size != SiteSetting.sequential_replies_threshold ||
              recent_posts_user_ids.detect { |u| u != @user.id }

    # If we got this far, log that we've nagged them about the sequential replies
    UserHistory.create!(action: UserHistory.actions[:notified_about_sequential_replies],
                        target_user_id: @user.id,
                        topic_id: @details[:topic_id])

    {
      id: 'sequential_replies',
      templateName: 'education',
      wait_for_typing: true,
      extraClass: 'education-message',
      body: PrettyText.cook(I18n.t('education.sequential_replies'))
    }
  end

  def check_dominating_topic
    return unless educate_reply?(:notified_about_dominating_topic)

    return if @topic.blank? ||
              @topic.user_id == @user.id ||
              @topic.posts_count < SiteSetting.summary_posts_required ||
              @topic.private_message?

    posts_by_user = @user.posts.where(topic_id: @topic.id).count

    ratio = (posts_by_user.to_f / @topic.posts_count.to_f)
    return if ratio < (SiteSetting.dominating_topic_minimum_percent.to_f / 100.0)

    # Log the topic notification
    UserHistory.create!(action: UserHistory.actions[:notified_about_dominating_topic],
                        target_user_id: @user.id,
                        topic_id: @details[:topic_id])

    {
      id: 'dominating_topic',
      templateName: 'education',
      wait_for_typing: true,
      extraClass: 'education-message',
      body: PrettyText.cook(I18n.t('education.dominating_topic', percent: (ratio * 100).round))
    }
  end

  def check_get_a_room(min_users_posted: 5)
    return unless educate_reply?(:notified_about_get_a_room)
    return unless @details[:post_id].present?

    reply_to_user_id = Post.where(id: @details[:post_id]).pluck(:user_id)[0]

    # Users's last x posts in the topic
    last_x_replies = @topic.
      posts.
      where(user_id: @user.id).
      order('created_at desc').
      limit(SiteSetting.get_a_room_threshold).
      pluck(:reply_to_user_id).
      find_all { |uid| uid != @user.id && uid == reply_to_user_id }

    return unless last_x_replies.size == SiteSetting.get_a_room_threshold
    return unless @topic.posts.count('distinct user_id') >= min_users_posted

    UserHistory.create!(action: UserHistory.actions[:notified_about_get_a_room],
                        target_user_id: @user.id,
                        topic_id: @details[:topic_id])

    reply_username = User.where(id: last_x_replies[0]).pluck_first(:username)

    {
      id: 'get_a_room',
      templateName: 'education',
      wait_for_typing: true,
      extraClass: 'education-message',
      body: PrettyText.cook(
        I18n.t(
          'education.get_a_room',
          count: SiteSetting.get_a_room_threshold,
          reply_username: reply_username,
          base_path: Discourse.base_path
        )
      )
    }
  end

  def check_reviving_old_topic
    return unless replying?
    return if @topic.nil? ||
              SiteSetting.warn_reviving_old_topic_age < 1 ||
              @topic.last_posted_at.nil? ||
              @topic.last_posted_at > SiteSetting.warn_reviving_old_topic_age.days.ago

    {
      id: 'reviving_old',
      templateName: 'education',
      wait_for_typing: false,
      extraClass: 'education-message',
      body: PrettyText.cook(
        I18n.t(
          'education.reviving_old_topic',
          time_ago: FreedomPatches::Rails4.time_ago_in_words(@topic.last_posted_at, false, scope: :'datetime.distance_in_words_verbose')
        )
      )
    }
  end

  private

  def educate_reply?(type)
    replying? &&
    @details[:topic_id] &&
    (@topic.present? && !@topic.private_message?) &&
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
