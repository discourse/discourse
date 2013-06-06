# The SpamRulesEnforcer class takes action against users based on flags that their posts
# receive, their trust level, etc.
class SpamRulesEnforcer

  include Rails.application.routes.url_helpers

  # The exclamation point means that this method may make big changes to posts and the user.
  def self.enforce!(user)
    SpamRulesEnforcer.new(user).enforce!
  end

  def self.block?(user)
    SpamRulesEnforcer.new(user).block?
  end

  def self.punish!(user)
    SpamRulesEnforcer.new(user).punish_user
  end

  def self.clear(user)
    SpamRulesEnforcer.new(user).clear_user
  end


  def initialize(user)
    @user = user
  end

  def enforce!
    punish_user if block?
    true
  end

  def block?
    @user.blocked? or
      (!@user.has_trust_level?(:basic) and
        SiteSetting.num_flags_to_block_new_user > 0 and
        SiteSetting.num_users_to_block_new_user > 0 and
        num_spam_flags_against_user >= SiteSetting.num_flags_to_block_new_user and
        num_users_who_flagged_spam_against_user >= SiteSetting.num_users_to_block_new_user)
  end

  def num_spam_flags_against_user
    Post.where(user_id: @user.id).sum(:spam_count)
  end

  def num_users_who_flagged_spam_against_user
    post_ids = Post.where('user_id = ? and spam_count > 0', @user.id).pluck(:id)
    return 0 if post_ids.empty?
    PostAction.spam_flags.where(post_id: post_ids).uniq.pluck(:user_id).size
  end

  def punish_user
    Post.update_all(["hidden = true, hidden_reason_id = COALESCE(hidden_reason_id, ?)", Post.hidden_reasons[:new_user_spam_threshold_reached]], user_id: @user.id)
    SystemMessage.create(@user, :too_many_spam_flags)
    notify_moderators
    @user.blocked = true
    @user.save
  end

  def clear_user
    SystemMessage.create(@user, :unblocked)
    @user.blocked = false
    @user.save
  end


  private

    def notify_moderators
      title = I18n.t("system_messages.user_automatically_blocked.subject_template", {username: @user.username})
      raw_body = I18n.t("system_messages.user_automatically_blocked.text_body_template", {username: @user.username, blocked_user_url: admin_user_path(@user.username)})
      PostCreator.create( Discourse.system_user,
                          target_group_names: [Group[:moderators].name],
                          archetype: Archetype.private_message,
                          subtype: TopicSubtype.system_message,
                          title: title,
                          raw: raw_body )
    end

end
