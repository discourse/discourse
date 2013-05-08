class Admin::GroupsController < Admin::AdminController
  def index
    groups = Group.order(:name).all
    render_serialized(groups, AdminGroupSerializer)
  end

  def refresh_automatic_groups
    Group.refresh_automatic_groups!
    render json: "ok"
  end

  def show
  end

  def users
    group = Group.find(params[:group_id].to_i)
    render_serialized(group.users, BasicUserSerializer)
  end
end
