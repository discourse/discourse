require_dependency 'user_destroyer'
require_dependency 'admin_user_index_query'
require_dependency 'admin_confirmation'

class Admin::UsersController < Admin::AdminController

  before_action :fetch_user, only: [:suspend,
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
                                    :silence,
                                    :unsilence,
                                    :trust_level,
                                    :trust_level_lock,
                                    :add_group,
                                    :remove_group,
                                    :primary_group,
                                    :generate_api_key,
                                    :revoke_api_key,
                                    :anonymize,
                                    :reset_bounce_score,
                                    :disable_second_factor,
                                    :delete_posts_batch]

  def index
    users = ::AdminUserIndexQuery.new(params).find_users

    opts = {}
    if params[:show_emails] == "true"
      StaffActionLogger.new(current_user).log_show_emails(users, context: request.path)
      opts[:emails_desired] = true
    end

    render_serialized(users, AdminUserListSerializer, opts)
  end

  def show
    @user = User.find_by(id: params[:id])
    raise Discourse::NotFound unless @user
    render_serialized(@user, AdminDetailedUserSerializer, root: false)
  end

  def delete_posts_batch
    deleted_posts = @user.delete_posts_in_batches(guardian)
    # staff action logs will have an entry for each post

    render json: { posts_deleted: deleted_posts.length }
  end

  # DELETE action to delete penalty history for a user
  def penalty_history

    # We don't delete any history, we merely remove the action type
    # with a removed type. It can still be viewed in the logs but
    # will not affect TL3 promotions.
    sql = <<~SQL
      UPDATE user_histories
      SET action = CASE
        WHEN action = :silence_user THEN :removed_silence_user
        WHEN action = :unsilence_user THEN :removed_unsilence_user
        WHEN action = :suspend_user THEN :removed_suspend_user
        WHEN action = :unsuspend_user THEN :removed_unsuspend_user
      END
      WHERE target_user_id = :user_id
        AND action IN (
          :silence_user,
          :suspend_user,
          :unsilence_user,
          :unsuspend_user
        )
    SQL

    DB.exec(
      sql,
      UserHistory.actions.slice(
        :silence_user,
        :suspend_user,
        :unsilence_user,
        :unsuspend_user,
        :removed_silence_user,
        :removed_unsilence_user,
        :removed_suspend_user,
        :removed_unsuspend_user
      ).merge(user_id: params[:user_id].to_i)
    )

    render json: success_json
  end

  def suspend
    guardian.ensure_can_suspend!(@user)
    @user.suspended_till = params[:suspend_until]
    @user.suspended_at = DateTime.now

    message = params[:message]

    user_history = nil

    User.transaction do
      @user.save!
      @user.revoke_api_key

      user_history = StaffActionLogger.new(current_user).log_user_suspend(
        @user,
        params[:reason],
        message: message,
        post_id: params[:post_id]
      )
    end
    @user.logged_out

    if message.present?
      Jobs.enqueue(
        :critical_user_email,
        type: :account_suspended,
        user_id: @user.id,
        user_history_id: user_history.id
      )
    end

    DiscourseEvent.trigger(
      :user_suspended,
      user: @user,
      reason: params[:reason],
      message: message,
      user_history: user_history,
      post_id: params[:post_id],
      suspended_till: params[:suspend_until],
      suspended_at: DateTime.now
    )

    perform_post_action

    render_json_dump(
      suspension: {
        suspended: true,
        suspend_reason: params[:reason],
        full_suspend_reason: user_history.try(:details),
        suspended_till: @user.suspended_till,
        suspended_at: @user.suspended_at
      }
    )
  end

  def unsuspend
    guardian.ensure_can_suspend!(@user)
    @user.suspended_till = nil
    @user.suspended_at = nil
    @user.save!
    StaffActionLogger.new(current_user).log_user_unsuspend(@user)

    DiscourseEvent.trigger(:user_unsuspended, user: @user)

    render_json_dump(
      suspension: {
        suspended: false
      }
    )
  end

  def log_out
    if @user
      @user.user_auth_tokens.destroy_all
      @user.logged_out
      render json: success_json
    else
      render json: { error: I18n.t('admin_js.admin.users.id_not_found') }, status: 404
    end
  end

  def refresh_browsers
    refresh_browser @user
    render body: nil
  end

  def revoke_admin
    guardian.ensure_can_revoke_admin!(@user)
    @user.revoke_admin!
    StaffActionLogger.new(current_user).log_revoke_admin(@user)
    render body: nil
  end

  def generate_api_key
    api_key = @user.generate_api_key(current_user)
    render_serialized(api_key, ApiKeySerializer)
  end

  def revoke_api_key
    @user.revoke_api_key
    render body: nil
  end

  def grant_admin
    AdminConfirmation.new(@user, current_user).create_confirmation
    render json: success_json
  end

  def revoke_moderation
    guardian.ensure_can_revoke_moderation!(@user)
    @user.revoke_moderation!
    StaffActionLogger.new(current_user).log_revoke_moderation(@user)
    render body: nil
  end

  def grant_moderation
    guardian.ensure_can_grant_moderation!(@user)
    @user.grant_moderation!
    StaffActionLogger.new(current_user).log_grant_moderation(@user)
    render_serialized(@user, AdminUserSerializer)
  end

  def add_group
    group = Group.find(params[:group_id].to_i)
    return render_json_error group unless group && !group.automatic

    group.add(@user)
    GroupActionLogger.new(current_user, group).log_add_user_to_group(@user)

    render body: nil
  end

  def remove_group
    group = Group.find(params[:group_id].to_i)
    return render_json_error group unless group && !group.automatic

    group.remove(@user)
    GroupActionLogger.new(current_user, group).log_remove_user_from_group(@user)

    render body: nil
  end

  def primary_group
    guardian.ensure_can_change_primary_group!(@user)

    if params[:primary_group_id].present?
      primary_group_id = params[:primary_group_id].to_i
      if group = Group.find(primary_group_id)
        if group.user_ids.include?(@user.id)
          @user.primary_group_id = primary_group_id
        end
      end
    else
      @user.primary_group_id = nil
    end

    @user.save!

    render body: nil
  end

  def trust_level
    guardian.ensure_can_change_trust_level!(@user)
    level = params[:level].to_i

    if @user.manual_locked_trust_level.nil?
      if [0, 1, 2].include?(level) && Promotion.send("tl#{level + 1}_met?", @user)
        @user.manual_locked_trust_level = level
        @user.save
      elsif level == 3 && Promotion.tl3_lost?(@user)
        @user.manual_locked_trust_level = level
        @user.save
      end
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
      return render_json_error I18n.t('errors.invalid_boolean')
    end

    @user.manual_locked_trust_level = (new_lock == "true") ? @user.trust_level : nil
    @user.save

    StaffActionLogger.new(current_user).log_lock_trust_level(@user)
    Promotion.recalculate(@user, current_user)

    render body: nil
  end

  def approve
    guardian.ensure_can_approve!(@user)
    @user.approve(current_user)
    render body: nil
  end

  def approve_bulk
    User.where(id: params[:users]).each do |u|
      u.approve(current_user) if guardian.can_approve?(u)
    end
    render body: nil
  end

  def activate
    guardian.ensure_can_activate!(@user)
    # ensure there is an active email token
    @user.email_tokens.create(email: @user.email) unless @user.email_tokens.active.exists?
    @user.activate
    StaffActionLogger.new(current_user).log_user_activate(@user, I18n.t('user.activated_by_staff'))
    render json: success_json
  end

  def deactivate
    guardian.ensure_can_deactivate!(@user)
    @user.deactivate
    StaffActionLogger.new(current_user).log_user_deactivate(@user, I18n.t('user.deactivated_by_staff'), params.slice(:context))
    refresh_browser @user
    render body: nil
  end

  def silence
    guardian.ensure_can_silence_user! @user

    message = params[:message]

    silencer = UserSilencer.new(
      @user,
      current_user,
      silenced_till: params[:silenced_till],
      reason: params[:reason],
      message_body: message,
      keep_posts: true,
      post_id: params[:post_id]
    )
    if silencer.silence && message.present?
      Jobs.enqueue(
        :critical_user_email,
        type: :account_silenced,
        user_id: @user.id,
        user_history_id: silencer.user_history.id
      )
    end
    perform_post_action

    render_json_dump(
      silence: {
        silenced: true,
        silence_reason: silencer.user_history.try(:details),
        silenced_till: @user.silenced_till,
        silenced_at: @user.silenced_at,
        silenced_by: BasicUserSerializer.new(current_user, root: false).as_json
      }
    )
  end

  def unsilence
    guardian.ensure_can_unsilence_user! @user
    UserSilencer.unsilence(@user, current_user)

    render_json_dump(
      unsilence: {
        silenced: false,
        silence_reason: nil,
        silenced_till: nil,
        silenced_at: nil
      }
    )
  end

  def reject_bulk
    success_count = 0
    d = UserDestroyer.new(current_user)

    User.where(id: params[:users]).each do |u|
      success_count += 1 if guardian.can_delete_user?(u) && d.destroy(u, params.slice(:context)) rescue UserDestroyer::PostsExistError
    end

    render json: {
      success: success_count,
      failed: (params[:users].try(:size) || 0) - success_count
    }
  end

  def disable_second_factor
    guardian.ensure_can_disable_second_factor!(@user)
    user_second_factor = @user.user_second_factors
    raise Discourse::InvalidParameters unless !user_second_factor.empty?

    user_second_factor.destroy_all
    StaffActionLogger.new(current_user).log_disable_second_factor_auth(@user)

    Jobs.enqueue(
      :critical_user_email,
      type: :account_second_factor_disabled,
      user_id: @user.id
    )

    render json: success_json
  end

  def destroy
    user = User.find_by(id: params[:id].to_i)
    guardian.ensure_can_delete_user!(user)

    options = params.slice(:block_email, :block_urls, :block_ip, :context, :delete_as_spammer)
    options[:delete_posts] = ActiveModel::Type::Boolean.new.cast(params[:delete_posts])
    options[:prepare_for_destroy] = true

    hijack do
      begin
        if UserDestroyer.new(current_user).destroy(user, options)
          render json: { deleted: true }
        else
          render json: {
            deleted: false,
            user: AdminDetailedUserSerializer.new(user, root: false).as_json
          }
        end
      rescue UserDestroyer::PostsExistError
        render json: {
          deleted: false,
          message: "User #{user.username} has #{user.post_count} posts, so they can't be deleted."
        }, status: 403
      end
    end
  end

  def badges
  end

  def tl3_requirements
  end

  def ip_info
    params.require(:ip)

    render json: DiscourseIpInfo.get(params[:ip], resolve_hostname: true)
  end

  def sync_sso
    return render body: nil, status: 404 unless SiteSetting.enable_sso

    begin
      sso = DiscourseSingleSignOn.parse("sso=#{params[:sso]}&sig=#{params[:sig]}")
    rescue DiscourseSingleSignOn::ParseError => e
      return render json: failed_json.merge(message: I18n.t("sso.login_error")), status: 422
    end

    begin
      user = sso.lookup_or_create_user
      render_serialized(user, AdminDetailedUserSerializer, root: false)
    rescue ActiveRecord::RecordInvalid => ex
      render json: failed_json.merge(message: ex.message), status: 403
    end
  end

  def delete_other_accounts_with_same_ip
    params.require(:ip)
    params.require(:exclude)
    params.require(:order)

    user_destroyer = UserDestroyer.new(current_user)
    options = {
      delete_posts: true,
      block_email: true,
      block_urls: true,
      block_ip: true,
      delete_as_spammer: true,
      context: I18n.t("user.destroy_reasons.same_ip_address", ip_address: params[:ip])
    }

    AdminUserIndexQuery.new(params).find_users(50).each do |user|
      user_destroyer.destroy(user, options)
    end

    render json: success_json
  end

  def total_other_accounts_with_same_ip
    params.require(:ip)
    params.require(:exclude)
    params.require(:order)

    render json: { total: AdminUserIndexQuery.new(params).count_users }
  end

  def invite_admin
    raise Discourse::InvalidAccess.new unless is_api?

    email = params[:email]
    unless user = User.find_by_email(email)
      name = params[:name] if params[:name].present?
      username = params[:username] if params[:username].present?

      user = User.new(email: email)
      user.password = SecureRandom.hex
      user.username = UserNameSuggester.suggest(username || name || email)
      user.name = User.suggest_name(name || username || email)
    end

    user.active = true
    user.save!
    user.grant_admin!
    user.change_trust_level!(4)
    user.email_tokens.update_all confirmed: true

    email_token = user.email_tokens.create(email: user.email)

    unless params[:send_email] == '0' || params[:send_email] == 'false'
      Jobs.enqueue(:critical_user_email,
                    type: :account_created,
                    user_id: user.id,
                    email_token: email_token.token)
    end

    render json: success_json.merge!(
      password_url: "#{Discourse.base_url}#{password_reset_token_path(token: email_token.token)}"
    )

  end

  def anonymize
    guardian.ensure_can_anonymize_user!(@user)
    if user = UserAnonymizer.new(@user, current_user).make_anonymous
      render json: success_json.merge(username: user.username)
    else
      render json: failed_json.merge(user: AdminDetailedUserSerializer.new(user, root: false).as_json)
    end
  end

  def reset_bounce_score
    guardian.ensure_can_reset_bounce_score!(@user)
    @user.user_stat&.reset_bounce_score!
    render json: success_json
  end

  private

  def perform_post_action
    return unless params[:post_id].present? &&
      params[:post_action].present?

    if post = Post.where(id: params[:post_id]).first
      case params[:post_action]
      when 'delete'
        PostDestroyer.new(current_user, post).destroy
      when 'edit'
        revisor = PostRevisor.new(post)

        # Take what the moderator edited in as gospel
        revisor.revise!(
          current_user,
          { raw:  params[:post_edit] },
          skip_validations: true,
          skip_revision: true
        )
      end
    end
  end

  def fetch_user
    @user = User.find_by(id: params[:user_id])
    raise Discourse::NotFound unless @user
  end

  def refresh_browser(user)
    MessageBus.publish "/file-change", ["refresh"], user_ids: [user.id]
  end

end
