require_dependency 'rate_limiter'

class InvitesController < ApplicationController

  skip_before_filter :check_xhr, except: [:perform_accept_invitation]
  skip_before_filter :preload_json, except: [:show]
  skip_before_filter :redirect_to_login_if_required

  before_filter :ensure_logged_in, only: [:destroy, :create, :create_invite_link, :resend_invite, :resend_all_invites, :upload_csv]
  before_filter :ensure_new_registrations_allowed, only: [:show, :perform_accept_invitation, :redeem_disposable_invite]
  before_filter :ensure_not_logged_in, only: [:show, :perform_accept_invitation, :redeem_disposable_invite]

  def show
    expires_now

    invite = Invite.find_by(invite_key: params[:id])

    if invite.present?
      store_preloaded("invite_info", MultiJson.dump({
        invited_by: UserNameSerializer.new(invite.invited_by, scope: guardian, root: false),
        email: invite.email,
        username: UserNameSuggester.suggest(invite.email)
      }))
      render layout: 'application'
    else
      flash.now[:error] = I18n.t('invite.not_found')
      render layout: 'no_ember'
    end
  end

  def perform_accept_invitation
    invite = Invite.find_by(invite_key: params[:id])

    if invite.present?
      begin
        user = invite.redeem(username: params[:username], password: params[:password])
        if user.present?
          log_on_user(user)

          # Send a welcome message if required
          user.enqueue_welcome_message('welcome_invite') if user.send_welcome_message
        end

        topic = user.present? ? invite.topics.first : nil

        render json: {
          success: true,
          redirect_to: topic.present? ? path("#{topic.relative_url}") : path("/")
        }
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
        render json: {
          success: false,
          errors: e.record&.errors&.to_hash || {}
        }
      end
    else
      render json: { success: false, message: I18n.t('invite.not_found') }
    end
  end

  def create
    params.require(:email)

    group_ids = Group.lookup_group_ids(params)

    guardian.ensure_can_invite_to_forum!(group_ids)

    invite_exists = Invite.where(email: params[:email], invited_by_id: current_user.id).first
    if invite_exists && !guardian.can_send_multiple_invites?(current_user)
      return render json: failed_json, status: 422
    end

    begin
      if Invite.invite_by_email(params[:email], current_user, _topic=nil,  group_ids, params[:custom_message])
        render json: success_json
      else
        render json: failed_json, status: 422
      end
    rescue => e
      render json: {errors: [e.message]}, status: 422
    end
  end

  def create_invite_link
    params.require(:email)
    group_ids = Group.lookup_group_ids(params)
    topic = Topic.find_by(id: params[:topic_id])
    guardian.ensure_can_invite_to_forum!(group_ids)

    invite_exists = Invite.where(email: params[:email], invited_by_id: current_user.id).first
    if invite_exists && !guardian.can_send_multiple_invites?(current_user)
      return render json: failed_json, status: 422
    end

    begin
      # generate invite link
      if invite_link = Invite.generate_invite_link(params[:email], current_user, topic, group_ids)
        render_json_dump(invite_link)
      else
        render json: failed_json, status: 422
      end
    rescue => e
      render json: {errors: [e.message]}, status: 422
    end
  end

  def create_disposable_invite
    guardian.ensure_can_create_disposable_invite!(current_user)
    params.permit(:username, :email, :quantity, :group_names)

    username_or_email = params[:username] ? fetch_username : fetch_email
    user = User.find_by_username_or_email(username_or_email)

    # generate invite tokens
    invite_tokens = Invite.generate_disposable_tokens(user, params[:quantity], params[:group_names])

    render_json_dump(invite_tokens)
  end

  def redeem_disposable_invite
    params.require(:email)
    params.permit(:username, :name, :topic)
    params[:email] = params[:email].split(' ').join('+')

    invite = Invite.find_by(invite_key: params[:token])

    if invite.present?
      user = Invite.redeem_from_token(params[:token], params[:email], params[:username], params[:name], params[:topic].to_i)
      if user.present?
        log_on_user(user)

        # Send a welcome message if required
        user.enqueue_welcome_message('welcome_invite') if user.send_welcome_message

        topic = invite.topics.first
        if topic.present?
          redirect_to path("#{topic.relative_url}")
          return
        end
      end
    end

    redirect_to path("/")
  end

  def destroy
    params.require(:email)

    invite = Invite.find_by(invited_by_id: current_user.id, email: params[:email])
    raise Discourse::InvalidParameters.new(:email) if invite.blank?
    invite.trash!(current_user)

    render nothing: true
  end

  def resend_invite
    params.require(:email)
    RateLimiter.new(current_user, "resend-invite-per-hour", 10, 1.hour).performed!

    invite = Invite.find_by(invited_by_id: current_user.id, email: params[:email])
    raise Discourse::InvalidParameters.new(:email) if invite.blank?
    invite.resend_invite
    render nothing: true

  rescue RateLimiter::LimitExceeded
    render_json_error(I18n.t("rate_limiter.slow_down"))
  end

  def resend_all_invites
    guardian.ensure_can_resend_all_invites!(current_user)

    Invite.resend_all_invites_from(current_user.id)
    render nothing: true
  end

  def upload_csv
    guardian.ensure_can_bulk_invite_to_forum!(current_user)

    file = params[:file] || params[:files].first
    name = params[:name] || File.basename(file.original_filename, ".*")
    extension = File.extname(file.original_filename)

    Scheduler::Defer.later("Upload CSV") do
      begin
        data = if extension.downcase == ".csv"
          path = Invite.create_csv(file, name)
          Jobs.enqueue(:bulk_invite, filename: "#{name}#{extension}", current_user_id: current_user.id)
          {url: path}
        else
          failed_json.merge(errors: [I18n.t("bulk_invite.file_should_be_csv")])
        end
      rescue
        failed_json.merge(errors: [I18n.t("bulk_invite.error")])
      end
      MessageBus.publish("/uploads/csv", data.as_json, user_ids: [current_user.id])
    end

    render json: success_json
  end

  def fetch_username
    params.require(:username)
    params[:username]
  end

  def fetch_email
    params.require(:email)
    params[:email]
  end

  def ensure_new_registrations_allowed
    unless SiteSetting.allow_new_registrations
      flash[:error] = I18n.t('login.new_registrations_disabled')
      render layout: 'no_ember'
      false
    end
  end

  def ensure_not_logged_in
    if current_user
      flash[:error] = I18n.t("login.already_logged_in", current_user: current_user.username)
      render layout: 'no_ember'
      false
    end
  end
end
