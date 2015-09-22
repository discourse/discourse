class InvitesController < ApplicationController

  # TODO tighten this, why skip check on everything?
  skip_before_filter :check_xhr, :preload_json
  skip_before_filter :redirect_to_login_if_required

  before_filter :ensure_logged_in, only: [:destroy, :create, :create_invite_link, :resend_invite, :check_csv_chunk, :upload_csv_chunk]
  before_filter :ensure_new_registrations_allowed, only: [:show, :redeem_disposable_invite]

  def show
    invite = Invite.find_by(invite_key: params[:id])

    if invite.present?
      user = invite.redeem
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

  def create
    params.require(:email)

    group_ids = Group.lookup_group_ids(params)

    guardian.ensure_can_invite_to_forum!(group_ids)

    invite_exists = Invite.where(email: params[:email], invited_by_id: current_user.id).first
    if invite_exists
      guardian.ensure_can_send_multiple_invites!(current_user)
    end

    if Invite.invite_by_email(params[:email], current_user, _topic=nil,  group_ids)
      render json: success_json
    else
      render json: failed_json, status: 422
    end
  end

  def create_invite_link
    params.require(:email)
    group_ids = Group.lookup_group_ids(params)
    topic = Topic.find_by(id: params[:topic_id])
    guardian.ensure_can_invite_to_forum!(group_ids)

    invite_exists = Invite.where(email: params[:email], invited_by_id: current_user.id).first
    if invite_exists
      guardian.ensure_can_send_multiple_invites!(current_user)
    end

    # generate invite link
    if invite_link = Invite.generate_invite_link(params[:email], current_user, topic, group_ids)
      render_json_dump(invite_link)
    else
      render json: failed_json, status: 422
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

    invite = Invite.find_by(invited_by_id: current_user.id, email: params[:email])
    raise Discourse::InvalidParameters.new(:email) if invite.blank?
    invite.resend_invite

    render nothing: true
  end

  def check_csv_chunk
    guardian.ensure_can_bulk_invite_to_forum!(current_user)

    filename           = params.fetch(:resumableFilename)
    identifier         = params.fetch(:resumableIdentifier)
    chunk_number       = params.fetch(:resumableChunkNumber)
    current_chunk_size = params.fetch(:resumableCurrentChunkSize).to_i

    # path to chunk file
    chunk = Invite.chunk_path(identifier, filename, chunk_number)
    # check chunk upload status
    status = HandleChunkUpload.check_chunk(chunk, current_chunk_size: current_chunk_size)

    render nothing: true, status: status
  end

  def upload_csv_chunk
    guardian.ensure_can_bulk_invite_to_forum!(current_user)

    filename = params.fetch(:resumableFilename)
    return render status: 415, text: I18n.t("bulk_invite.file_should_be_csv") unless (filename.to_s.end_with?(".csv") || filename.to_s.end_with?(".txt"))

    file               = params.fetch(:file)
    identifier         = params.fetch(:resumableIdentifier)
    chunk_number       = params.fetch(:resumableChunkNumber).to_i
    chunk_size         = params.fetch(:resumableChunkSize).to_i
    total_size         = params.fetch(:resumableTotalSize).to_i
    current_chunk_size = params.fetch(:resumableCurrentChunkSize).to_i

    # path to chunk file
    chunk = Invite.chunk_path(identifier, filename, chunk_number)
    # upload chunk
    HandleChunkUpload.upload_chunk(chunk, file: file)

    uploaded_file_size = chunk_number * chunk_size
    # when all chunks are uploaded
    if uploaded_file_size + current_chunk_size >= total_size
      # handle bulk_invite processing in a background thread
      Jobs.enqueue(:bulk_invite, filename: filename, identifier: identifier, chunks: chunk_number, current_user_id: current_user.id)
    end

    render nothing: true
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
end
