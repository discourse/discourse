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
    group.visible = params[:visible] == "true"

    if group.save
      render_serialized(group, BasicGroupSerializer)
    else
      render_json_error group
    end
  end

  def update
    group = Group.find(params[:id].to_i)

    group.alias_level = params[:alias_level].to_i if params[:alias_level].present?
    group.visible = params[:visible] == "true"
    # group rename is ignored for automatic groups
    group.name = params[:name] if params[:name] && !group.automatic

    if group.save
      render json: success_json
    else
      render_json_error group
    end
  end

  def destroy
    group = Group.find(params[:id].to_i)

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
    group = Group.find(params.require(:group_id).to_i)
    usernames = params.require(:usernames)

    return can_not_modify_automatic if group.automatic

    usernames.split(",").each do |username|
      if user = User.find_by_username(username)
        group.add(user)
      end
    end

    if group.save
      render json: success_json
    else
      render_json_error(group)
    end
  end

  def remove_member
    group = Group.find(params.require(:group_id).to_i)
    user_id = params.require(:user_id).to_i

    return can_not_modify_automatic if group.automatic

    group.users.delete(user_id)

    if group.save
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
