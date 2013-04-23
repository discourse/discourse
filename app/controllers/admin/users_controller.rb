require_dependency 'user_destroyer'

class Admin::UsersController < Admin::AdminController

  def index
    # Sort order
    if params[:query] == "active"
      @users = User.order("COALESCE(last_seen_at, to_date('1970-01-01', 'YYYY-MM-DD')) DESC, username")
    else
      @users = User.order("created_at DESC, username")
    end

    if ['newuser', 'basic', 'regular', 'leader', 'elder'].include?(params[:query])
      @users = @users.where('trust_level = ?', TrustLevel.levels[params[:query].to_sym])
    end

    @users = @users.where('admin = ?', true)      if params[:query] == 'admins'
    @users = @users.where('moderator = ?', true)  if params[:query] == 'moderators'
    @users = @users.where('approved = false')     if params[:query] == 'pending'
    @users = @users.where('username_lower like :filter or email like :filter', filter: "%#{params[:filter]}%") if params[:filter].present?
    @users = @users.take(100)
    render_serialized(@users, AdminUserSerializer)
  end

  def show
    @user = User.where(username_lower: params[:id]).first
    raise Discourse::NotFound.new unless @user
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
    render nothing: true
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

  def revoke_moderation
    @moderator = User.where(id: params[:user_id]).first
    guardian.ensure_can_revoke_moderation!(@moderator)
    @moderator.moderator = false
    @moderator.save
    render nothing: true
  end

  def grant_moderation
    @user = User.where(id: params[:user_id]).first
    guardian.ensure_can_grant_moderation!(@user)
    @user.moderator = true
    @user.save
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

  def destroy
    user = User.where(id: params[:id]).first
    guardian.ensure_can_delete_user!(user)
    if UserDestroyer.new(current_user).destroy(user)
      render json: {deleted: true}
    else
      render json: {deleted: false, user: AdminDetailedUserSerializer.new(user, root: false).as_json}
    end
  end

end
