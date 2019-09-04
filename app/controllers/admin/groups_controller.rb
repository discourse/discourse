# frozen_string_literal: true

class Admin::GroupsController < Admin::AdminController
  def bulk
  end

  def bulk_perform
    group = Group.find_by(id: params[:group_id].to_i)
    raise Discourse::NotFound unless group
    users_added = 0

    users = (params[:users] || []).map { |user| user.downcase!; user }
    valid_emails = {}
    valid_usernames = {}

    valid_users = User.joins(:user_emails)
      .where("username_lower IN (:users) OR lower(user_emails.email) IN (:users)", users: users)
      .pluck(:id, :username_lower, :"user_emails.email")

    valid_users.map! do |id, username_lower, email|
      valid_emails[email] = valid_usernames[username_lower] = id
      id
    end

    valid_users.uniq!
    invalid_users = users.reject { |u| valid_emails[u] || valid_usernames[u] }
    group.bulk_add(valid_users) if valid_users.present?
    users_added = valid_users.count

    response = success_json.merge(users_not_added: invalid_users)

    if users_added > 0
      response[:message] = I18n.t('groups.success.bulk_add', count: users_added)
    end

    render json: response
  end

  def create
    attributes = group_params.to_h.except(:owner_usernames, :usernames)
    group = Group.new(attributes)

    unless group_params[:allow_membership_requests]
      group.membership_request_template = nil
    end

    if group_params[:owner_usernames].present?
      owner_ids = User.where(
        username: group_params[:owner_usernames].split(",")
      ).pluck(:id)

      owner_ids.each do |user_id|
        group.group_users.build(user_id: user_id, owner: true)
      end
    end

    if group_params[:usernames].present?
      user_ids = User.where(username: group_params[:usernames].split(",")).pluck(:id)
      user_ids -= owner_ids if owner_ids

      user_ids.each do |user_id|
        group.group_users.build(user_id: user_id)
      end
    end

    if group.save
      group.restore_user_count!
      render_serialized(group, BasicGroupSerializer)
    else
      render_json_error group
    end
  end

  def destroy
    group = Group.find_by(id: params[:id])
    raise Discourse::NotFound unless group

    if group.automatic
      can_not_modify_automatic
    else
      group.destroy!
      render json: success_json
    end
  end

  def add_owners
    group = Group.find_by(id: params.require(:id))
    raise Discourse::NotFound unless group

    return can_not_modify_automatic if group.automatic
    users = User.where(username: group_params[:usernames].split(","))

    users.each do |user|
      group_action_logger = GroupActionLogger.new(current_user, group)

      if !group.users.include?(user)
        group.add(user)
        group_action_logger.log_add_user_to_group(user)
      end
      group.group_users.where(user_id: user.id).update_all(owner: true)
      group_action_logger.log_make_user_group_owner(user)
    end

    group.restore_user_count!

    render json: success_json.merge!(usernames: users.pluck(:username))
  end

  def remove_owner
    group = Group.find_by(id: params.require(:id))
    raise Discourse::NotFound unless group

    return can_not_modify_automatic if group.automatic

    user = User.find(params[:user_id].to_i)
    group.group_users.where(user_id: user.id).update_all(owner: false)
    GroupActionLogger.new(current_user, group).log_remove_user_as_group_owner(user)

    Group.reset_counters(group.id, :group_users)

    render json: success_json
  end

  protected

  def can_not_modify_automatic
    render json: { errors: I18n.t('groups.errors.can_not_modify_automatic') }, status: 422
  end

  private

  def group_params
    permitted = [
      :name,
      :mentionable_level,
      :messageable_level,
      :visibility_level,
      :members_visibility_level,
      :automatic_membership_email_domains,
      :automatic_membership_retroactive,
      :title,
      :primary_group,
      :grant_trust_level,
      :incoming_email,
      :flair_url,
      :flair_bg_color,
      :flair_color,
      :bio_raw,
      :public_admission,
      :public_exit,
      :allow_membership_requests,
      :full_name,
      :default_notification_level,
      :membership_request_template,
      :owner_usernames,
      :usernames,
      :publish_read_state
    ]
    custom_fields = Group.editable_group_custom_fields
    permitted << { custom_fields: custom_fields } unless custom_fields.blank?

    params.require(:group).permit(permitted)
  end
end
