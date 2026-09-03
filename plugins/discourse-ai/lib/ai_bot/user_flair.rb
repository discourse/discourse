# frozen_string_literal: true

module DiscourseAi::AiBot::UserFlair
  GROUP_NAME = "discourse_ai_users"
  FLAIR_ICON = "discourse-ai"

  def self.sync_all!
    user_ids = associated_user_ids
    group = Group.find_by(name: GROUP_NAME)
    return if user_ids.empty? && !group

    if user_ids.any?
      group = ensure_group!
      group.bulk_add(user_ids, automatic: true)
      User
        .where(id: user_ids)
        .where("flair_group_id IS DISTINCT FROM ?", group.id)
        .update_all(flair_group_id: group.id)
    end

    stale_users = group.group_users
    stale_users = stale_users.where.not(user_id: user_ids) if user_ids.any?
    stale_user_ids = stale_users.pluck(:user_id)
    group.bulk_remove(stale_user_ids) if stale_user_ids.any?
  end

  def self.sync_user_ids!(user_ids)
    user_ids.compact.uniq.each { |user_id| sync_user!(user_id) }
  end

  def self.sync_user!(user_id)
    user = User.find_by(id: user_id)
    return if !user

    if associated_user?(user_id)
      group = ensure_group!
      group.add(user, automatic: true)
      user.update!(flair_group_id: group.id) if user.flair_group_id != group.id
    elsif group = Group.find_by(name: GROUP_NAME)
      group.remove(user)
    end
  end

  def self.associated_user_ids
    AiAgent
      .where.not(user_id: nil)
      .pluck(:user_id)
      .concat(LlmModel.where.not(user_id: nil).pluck(:user_id))
      .uniq
  end
  private_class_method :associated_user_ids

  def self.associated_user?(user_id)
    AiAgent.exists?(user_id: user_id) || LlmModel.exists?(user_id: user_id)
  end
  private_class_method :associated_user?

  def self.ensure_group!
    group = Group.find_or_initialize_by(name: GROUP_NAME)
    group.assign_attributes(
      automatic: true,
      flair_icon: FLAIR_ICON,
      full_name: I18n.t("discourse_ai.ai_bot.ai_users"),
      mentionable_level: Group::ALIAS_LEVELS[:nobody],
      messageable_level: Group::ALIAS_LEVELS[:nobody],
      visibility_level: Group.visibility_levels[:staff],
      members_visibility_level: Group.visibility_levels[:staff],
    )
    group.save! if group.changed?
    group
  rescue ActiveRecord::RecordNotUnique
    retry
  end
  private_class_method :ensure_group!
end
