class Admin::GroupsController < Admin::AdminController

  def index
    groups = Group.order(:name)

    if search = params[:search]
      search = search.to_s
      groups = groups.where("name ILIKE ?", "%#{search}%")
    end

    if params[:ignore_automatic].to_s == "true"
      groups = groups.where(automatic: false)
    end

    render_serialized(groups, BasicGroupSerializer)
  end

  def show
    render nothing: true
  end

  def create
    group = Group.new

    group.name = (params[:name] || '').strip
    save_group(group)
  end

  def update
    group = Group.find(params[:id])

    # group rename is ignored for automatic groups
    group.name = params[:name] if params[:name] && !group.automatic
    save_group(group)
  end

  def save_group(group)
    group.alias_level = params[:alias_level].to_i if params[:alias_level].present?
    group.visible = params[:visible] == "true"
    grant_trust_level = params[:grant_trust_level].to_i
    group.grant_trust_level = (grant_trust_level > 0 && grant_trust_level <= 4) ? grant_trust_level : nil

    group.automatic_membership_email_domains = params[:automatic_membership_email_domains] unless group.automatic
    group.automatic_membership_retroactive = params[:automatic_membership_retroactive] == "true" unless group.automatic

    group.primary_group = group.automatic ? false : params["primary_group"] == "true"

    title = params[:title] if params[:title].present?
    group.title = group.automatic ? nil : title

    if group.save
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

  def add_members
    group = Group.find(params.require(:id))

    return can_not_modify_automatic if group.automatic

    if params[:usernames].present?
      users = User.where(username: params[:usernames].split(","))
    elsif params[:user_ids].present?
      users = User.find(params[:user_ids].split(","))
    elsif params[:user_emails].present?
      users = User.where(email: params[:user_emails].split(","))
    else
      raise Discourse::InvalidParameters.new('user_ids or usernames or user_emails must be present')
    end

    users.each do |user|
      if !group.users.include?(user)
        group.add(user)
      else
        return render_json_error I18n.t('groups.errors.member_already_exist', username: user.username)
      end
    end

    if group.save
      render json: success_json
    else
      render_json_error(group)
    end
  end

  def remove_member
    group = Group.find(params.require(:id))

    return can_not_modify_automatic if group.automatic

    if params[:user_id].present?
      user = User.find(params[:user_id])
    elsif params[:username].present?
      user = User.find_by_username(params[:username])
    else
      raise Discourse::InvalidParameters.new('user_id or username must be present')
    end

    user.primary_group_id = nil if user.primary_group_id == group.id

    group.users.delete(user.id)

    if group.save && user.save
      render json: success_json
    else
      render_json_error(group)
    end
  end

  protected

    def can_not_modify_automatic
      render json: {errors: I18n.t('groups.errors.can_not_modify_automatic')}, status: 422
    end
end
