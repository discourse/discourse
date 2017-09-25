class Admin::GroupsController < Admin::AdminController
  def index
    groups = Group.order(:name).where("groups.id <> ?", Group::AUTO_GROUPS[:everyone])

    if search = params[:search].to_s
      groups = groups.where("name ILIKE ?", "%#{search}%")
    end

    if params[:ignore_automatic].to_s == "true"
      groups = groups.where(automatic: false)
    end

    render_serialized(groups, BasicGroupSerializer)
  end

  def show
    render body: nil
  end

  def bulk
    render body: nil
  end

  def bulk_perform
    group = Group.find(params[:group_id].to_i)
    users_added = 0
    if group.present?
      users = (params[:users] || []).map { |u| u.downcase }
      valid_emails = {}
      valid_usernames = {}

      valid_users = User.joins(:user_emails)
        .where("username_lower IN (:users) OR user_emails.email IN (:users)", users: users)
        .pluck(:id, :username_lower, :"user_emails.email")

      valid_users.map! do |id, username_lower, email|
        valid_emails[email] = valid_usernames[username_lower] = id
        id
      end
      valid_users.uniq!
      invalid_users = users.reject! { |u| valid_emails[u] || valid_usernames[u] }
      group.bulk_add(valid_users) if valid_users.present?
      users_added = valid_users.count
    end

    render json: { success: true, message: I18n.t('groups.success.bulk_add', users_added: users_added), users_not_added: invalid_users }
  end

  def create
    save_group(Group.new)
  end

  def update
    group = Group.find(params[:id])

    # group rename is ignored for automatic groups
    group.name = group_params[:name] if group_params[:name] && !group.automatic
    save_group(group) { |g| GroupActionLogger.new(current_user, g).log_change_group_settings }
  end

  def save_group(group)
    group.name = group_params[:name] if group_params[:name].present? && !group.automatic
    group.mentionable_level = group_params[:mentionable_level].to_i if group_params[:mentionable_level].present?
    group.messageable_level = group_params[:messageable_level].to_i if group_params[:messageable_level].present?

    if group_params[:visibility_level]
      group.visibility_level = group_params[:visibility_level]
    end

    grant_trust_level = group_params[:grant_trust_level].to_i
    group.grant_trust_level = (grant_trust_level > 0 && grant_trust_level <= 4) ? grant_trust_level : nil

    group.automatic_membership_email_domains = group_params[:automatic_membership_email_domains] unless group.automatic
    group.automatic_membership_retroactive = group_params[:automatic_membership_retroactive] == "true" unless group.automatic

    group.primary_group = group.automatic ? false : group_params["primary_group"] == "true"

    group.incoming_email = group.automatic ? nil : group_params[:incoming_email]

    title = group_params[:title] if group_params[:title].present?
    group.title = group.automatic ? nil : title

    group.flair_url      = group_params[:flair_url].presence
    group.flair_bg_color = group_params[:flair_bg_color].presence
    group.flair_color    = group_params[:flair_color].presence

    %i{public_admission public_exit}.each do |key|
      if group_params[key]
        group.public_send("#{key}=", group_params[key])
      end
    end

    group.bio_raw = group_params[:bio_raw] if group_params[:bio_raw]
    group.full_name = group_params[:full_name] if group_params[:full_name]

    if group_params.key?(:default_notification_level)
      group.default_notification_level = group_params[:default_notification_level]
    end

    if group_params[:allow_membership_requests]
      group.allow_membership_requests = group_params[:allow_membership_requests]
      group.membership_request_template = group_params[:membership_request_template]
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

      yield(group) if block_given?

      render_serialized(group, BasicGroupSerializer)
    else
      render_json_error group
    end
  end

  def destroy
    group = Group.find(params[:id])

    if group.automatic
      can_not_modify_automatic
    else
      group.destroy
      render json: success_json
    end
  end

  def refresh_automatic_groups
    Group.refresh_automatic_groups!
    render json: success_json
  end

  def add_owners
    group = Group.find(params.require(:id))
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

    render json: success_json
  end

  def remove_owner
    group = Group.find(params.require(:id))
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
    params.require(:group).permit(
      :name,
      :mentionable_level,
      :messageable_level,
      :visibility_level,
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
      :usernames,
      :owner_usernames,
      :membership_request_template
    )
  end
end
