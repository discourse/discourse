require_dependency 'user_destroyer'
require_dependency 'admin_user_index_query'

class Admin::UsersController < Admin::AdminController

  before_filter :fetch_user, only: [:suspend,
                                    :unsuspend,
                                    :refresh_browsers,
                                    :log_out,
                                    :revoke_admin,
                                    :grant_admin,
                                    :revoke_moderation,
                                    :grant_moderation,
                                    :approve,
                                    :activate,
                                    :deactivate,
                                    :block,
                                    :unblock,
                                    :trust_level,
                                    :trust_level_lock,
                                    :add_group,
                                    :remove_group,
                                    :primary_group,
                                    :generate_api_key,
                                    :revoke_api_key]

  def index
    query = ::AdminUserIndexQuery.new(params)
    render_serialized(query.find_users, AdminUserSerializer)
  end

  def show
    @user = User.find_by(username_lower: params[:id])
    raise Discourse::NotFound.new unless @user
    render_serialized(@user, AdminDetailedUserSerializer, root: false)
  end

  def delete_all_posts
    @user = User.find_by(id: params[:user_id])
    @user.delete_all_posts!(guardian)
    render nothing: true
  end

  def suspend
    guardian.ensure_can_suspend!(@user)
    @user.suspended_till = params[:duration].to_i.days.from_now
    @user.suspended_at = DateTime.now
    @user.save!
    StaffActionLogger.new(current_user).log_user_suspend(@user, params[:reason])
    render nothing: true
  end

  def unsuspend
    guardian.ensure_can_suspend!(@user)
    @user.suspended_till = nil
    @user.suspended_at = nil
    @user.save!
    StaffActionLogger.new(current_user).log_user_unsuspend(@user)
    render nothing: true
  end

  def log_out
    @user.auth_token = nil
    @user.save!
    render nothing: true
  end

  def refresh_browsers
    refresh_browser @user
    render nothing: true
  end

  def revoke_admin
    guardian.ensure_can_revoke_admin!(@user)
    @user.revoke_admin!
    render nothing: true
  end

  def generate_api_key
    api_key = @user.generate_api_key(current_user)
    render_serialized(api_key, ApiKeySerializer)
  end

  def revoke_api_key
    @user.revoke_api_key
    render nothing: true
  end

  def grant_admin
    guardian.ensure_can_grant_admin!(@user)
    @user.grant_admin!
    render_serialized(@user, AdminUserSerializer)
  end

  def revoke_moderation
    guardian.ensure_can_revoke_moderation!(@user)
    @user.revoke_moderation!
    render nothing: true
  end

  def grant_moderation
    guardian.ensure_can_grant_moderation!(@user)
    @user.grant_moderation!
    render_serialized(@user, AdminUserSerializer)
  end

  def add_group
    group = Group.find(params[:group_id].to_i)
    return render_json_error group unless group && !group.automatic
    group.users << @user
    render nothing: true
  end

  def remove_group
    group = Group.find(params[:group_id].to_i)
    return render_json_error group unless group && !group.automatic
    group.users.delete(@user)
    render nothing: true
  end


  def primary_group
    guardian.ensure_can_change_primary_group!(@user)
    @user.primary_group_id = params[:primary_group_id]
    @user.save!
    render nothing: true
  end

  def trust_level
    guardian.ensure_can_change_trust_level!(@user)
    level = params[:level].to_i


    if !@user.trust_level_locked && [0,1,2].include?(level) && Promotion.send("tl#{level+1}_met?", @user)
      @user.trust_level_locked = true
      @user.save
    end

    if !@user.trust_level_locked && level == 3 && Promotion.tl3_lost?(@user)
      @user.trust_level_locked = true
      @user.save
    end

    @user.change_trust_level!(level, log_action_for: current_user)

    render_serialized(@user, AdminUserSerializer)
  rescue Discourse::InvalidAccess => e
    render_json_error(e.message)
  end

  def trust_level_lock
    guardian.ensure_can_change_trust_level!(@user)

    new_lock = params[:locked].to_s
    unless new_lock =~ /true|false/
      return render_json_error I18n.t('errors.invalid_boolaen')
    end

    @user.trust_level_locked = new_lock == "true"
    @user.save

    unless @user.trust_level_locked
      p = Promotion.new(@user)
      2.times{ p.review }
      p.review_tl2
      if @user.trust_level == 3 && Promotion.tl3_lost?(@user)
        @user.change_trust_level!(2, log_action_for: current_user)
      end
    end

    render nothing: true
  end

  def approve
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

  def activate
    guardian.ensure_can_activate!(@user)
    @user.activate
    render nothing: true
  end

  def deactivate
    guardian.ensure_can_deactivate!(@user)
    @user.deactivate
    refresh_browser @user
    render nothing: true
  end

  def block
    guardian.ensure_can_block_user! @user
    UserBlocker.block(@user, current_user)
    render nothing: true
  end

  def unblock
    guardian.ensure_can_unblock_user! @user
    UserBlocker.unblock(@user, current_user)
    render nothing: true
  end

  def reject_bulk
    success_count = 0
    d = UserDestroyer.new(current_user)

    User.where(id: params[:users]).each do |u|
      success_count += 1 if guardian.can_delete_user?(u) and d.destroy(u, params.slice(:context)) rescue UserDestroyer::PostsExistError
    end

    render json: {
      success: success_count,
      failed: (params[:users].try(:size) || 0) - success_count
    }
  end

  def destroy
    user = User.find_by(id: params[:id].to_i)
    guardian.ensure_can_delete_user!(user)
    begin
      options = params.slice(:delete_posts, :block_email, :block_urls, :block_ip, :context, :delete_as_spammer)
      if UserDestroyer.new(current_user).destroy(user, options)
        render json: { deleted: true }
      else
        render json: {
          deleted: false,
          user: AdminDetailedUserSerializer.new(user, root: false).as_json
        }
      end
    rescue UserDestroyer::PostsExistError
      raise Discourse::InvalidAccess.new("User #{user.username} has #{user.post_count} posts, so can't be deleted.")
    end
  end

  def badges
  end

  def tl3_requirements
  end

  def ip_info
    params.require(:ip)
    ip = params[:ip]

    # should we cache results in redis?
    location = Excon.get("http://ipinfo.io/#{ip}/json", read_timeout: 30, connect_timeout: 30).body rescue nil

    render json: location
  end

  def sync_sso
    unless SiteSetting.enable_sso
      render nothing: true, status: 404
      return
    end

    sso = DiscourseSingleSignOn.parse("sso=#{params[:sso]}&sig=#{params[:sig]}")
    user = sso.lookup_or_create_user

    render_serialized(user, AdminDetailedUserSerializer, root: false)
  end

  private

    def fetch_user
      @user = User.find_by(id: params[:user_id])
    end

    def refresh_browser(user)
      MessageBus.publish "/file-change", ["refresh"], user_ids: [user.id]
    end

end
