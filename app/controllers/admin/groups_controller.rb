# frozen_string_literal: true

class Admin::GroupsController < Admin::AdminController
  def create
    guardian.ensure_can_create_group!

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
      details = { name: group.name }
      details[:grant_trust_level] = group.grant_trust_level if group.grant_trust_level

      StaffActionLogger.new(current_user).log_custom('delete_group', details)
      group.destroy!
      render json: success_json
    end
  end

  def add_owners
    group = Group.find_by(id: params.require(:id))
    raise Discourse::NotFound unless group

    return can_not_modify_automatic if group.automatic
    guardian.ensure_can_edit_group!(group)

    users = User.where(username: group_params[:usernames].split(","))

    users.each do |user|
      group_action_logger = GroupActionLogger.new(current_user, group)

      if !group.users.include?(user)
        group.add(user)
        group_action_logger.log_add_user_to_group(user)
      end
      group.group_users.where(user_id: user.id).update_all(owner: true)
      group_action_logger.log_make_user_group_owner(user)

      if group_params[:notify_users] == "true" || group_params[:notify_users] == true
        group.notify_added_to_group(user, owner: true)
      end
    end

    group.restore_user_count!

    render json: success_json.merge!(usernames: users.pluck(:username))
  end

  def remove_owner
    group = Group.find_by(id: params.require(:id))
    raise Discourse::NotFound unless group

    return can_not_modify_automatic if group.automatic
    guardian.ensure_can_edit_group!(group)

    if params[:user_id].present?
      users = [User.find_by(id: params[:user_id].to_i)]
    elsif usernames = group_params[:usernames].presence
      users = User.where(username: usernames.split(","))
    else
      raise Discourse::InvalidParameters.new(:user_id)
    end

    users.each do |user|
      group.group_users.where(user_id: user.id).update_all(owner: false)
      GroupActionLogger.new(current_user, group).log_remove_user_as_group_owner(user)
    end

    Group.reset_counters(group.id, :group_users)

    render json: success_json
  end

  def set_primary
    group = Group.find_by(id: params.require(:id))
    raise Discourse::NotFound unless group

    users = User.where(username: group_params[:usernames].split(","))
    users.each { |user| guardian.ensure_can_change_primary_group!(user) }
    users.update_all(primary_group_id: params[:primary] == "true" ? group.id : nil)

    render json: success_json
  end

  def automatic_membership_count
    domains = Group.get_valid_email_domains(params.require(:automatic_membership_email_domains))
    group_id = params[:id]
    user_count = 0

    if domains.present?
      if group_id.present?
        group = Group.find_by(id: group_id)
        raise Discourse::NotFound unless group

        return can_not_modify_automatic if group.automatic

        existing_domains = group.automatic_membership_email_domains&.split("|") || []
        domains -= existing_domains
      end

      user_count = Group.automatic_membership_users(domains.join("|")).count
    end

    render json: { user_count: user_count }
  end

  protected

  def can_not_modify_automatic
    render_json_error(I18n.t('groups.errors.can_not_modify_automatic'))
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
      :title,
      :primary_group,
      :grant_trust_level,
      :incoming_email,
      :flair_icon,
      :flair_upload_id,
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
      :publish_read_state,
      :notify_users
    ]
    custom_fields = DiscoursePluginRegistry.editable_group_custom_fields
    permitted << { custom_fields: custom_fields } unless custom_fields.blank?

    if guardian.can_associate_groups?
      permitted << { associated_group_ids: [] }
    end

    permitted = permitted | DiscoursePluginRegistry.group_params

    params.require(:group).permit(permitted)
  end
end
