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

  def bulk
    render nothing: true
  end

  def bulk_perform
    group = Group.find(params[:group_id].to_i)
    if group.present?
      users = (params[:users] || []).map {|u| u.downcase}
      user_ids = User.where("username_lower in (:users) OR email IN (:users)", users: users).pluck(:id)
      group.bulk_add(user_ids) if user_ids.present?
    end

    render json: success_json
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

    group.incoming_email = group.automatic ? nil : params[:incoming_email]

    title = params[:title] if params[:title].present?
    group.title = group.automatic ? nil : title

    if group.save
      Group.reset_counters(group.id, :group_users)
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

    users = User.where(username: params[:usernames].split(","))

    users.each do |user|
      if !group.users.include?(user)
        group.add(user)
      end
      group.group_users.where(user_id: user.id).update_all(owner: true)
    end

    Group.reset_counters(group.id, :group_users)

    render json: success_json
  end

  def remove_owner
    group = Group.find(params.require(:id))
    return can_not_modify_automatic if group.automatic

    user = User.find(params[:user_id].to_i)
    group.group_users.where(user_id: user.id).update_all(owner: false)

    Group.reset_counters(group.id, :group_users)

    render json: success_json
  end

  protected

    def can_not_modify_automatic
      render json: {errors: I18n.t('groups.errors.can_not_modify_automatic')}, status: 422
    end
end
