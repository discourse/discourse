class Admin::GroupsController < Admin::AdminController
  def index
    groups = Group.order(:name).all
    render_serialized(groups, BasicGroupSerializer)
  end

  def refresh_automatic_groups
    Group.refresh_automatic_groups!
    render json: "ok"
  end

  def users
    group = Group.find(params[:group_id].to_i)
    render_serialized(group.users.limit(100).to_a, BasicUserSerializer)
  end

  def update
    group = Group.find(params[:id].to_i)
    render_json_error if group.automatic
    group.usernames = params[:group][:usernames]
    group.name = params[:group][:name] if params[:name]
    group.save!
    render json: "ok"
  end

  def create
    group = Group.new
    group.name = params[:group][:name]
    group.usernames = params[:group][:usernames] if params[:group][:usernames]
    group.save!
    render_serialized(group, BasicGroupSerializer)
  end

  def destroy
    group = Group.find(params[:id].to_i)
    render_json_error if group.automatic
    group.destroy
    render json: "ok"
  end
end
