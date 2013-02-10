class Admin::UsersController < Admin::AdminController

  def index
    # Sort order
    if params[:query] == "active"
      @users = User.order("COALESCE(last_seen_at, '1970-01-01') DESC, username")
    else
      @users = User.order("created_at DESC, username")
    end

    @users = @users.where('approved = false') if params[:query] == 'pending'
    @users = @users.where('username_lower like :filter or email like :filter', filter: "%#{params[:filter]}%") if params[:filter].present?
    @users = @users.take(100)
    render_serialized(@users, AdminUserSerializer)
  end

  def show
    @user = User.where(username_lower: params[:id]).first
    render_serialized(@user, AdminDetailedUserSerializer, root: false)
  end

  def delete_all_posts
    @user = User.where(id: params[:user_id]).first
    @user.delete_all_posts!(guardian)
    render nothing: true
  end
  def ban
    @user = User.where(id: params[:user_id]).first
    guardian.ensure_can_ban!(@user)
    @user.banned_till = params[:duration].to_i.days.from_now
    @user.banned_at = DateTime.now
    @user.save!
    # TODO logging
    render nothing: true
  end

  def unban
    @user = User.where(id: params[:user_id]).first
    guardian.ensure_can_ban!(@user)
    @user.banned_till = nil
    @user.banned_at = nil
    @user.save!
    # TODO logging
    render nothing: true
  end

  def refresh_browsers
    @user = User.where(id: params[:user_id]).first
    MessageBus.publish "/file-change", ["refresh"], user_ids: [@user.id]
  end

  def revoke_admin
    @admin = User.where(id: params[:user_id]).first
    guardian.ensure_can_revoke_admin!(@admin)
    @admin.update_column(:admin, false)
    render nothing: true
  end

  def grant_admin
    @user = User.where(id: params[:user_id]).first
    guardian.ensure_can_grant_admin!(@user)
    @user.update_column(:admin, true)
    render_serialized(@user, AdminUserSerializer)
  end

  def approve
    @user = User.where(id: params[:user_id]).first
    guardian.ensure_can_approve!(@user)
    @user.approve(current_user)
    render nothing: true
  end

  def approve_bulk
    User.where(id: params[:users]).each do |u|
      u.approve(current_user) if guardian.can_approve?(u)
    end
    render nothing: true
  end

end

