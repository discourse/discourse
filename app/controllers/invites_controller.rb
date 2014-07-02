class InvitesController < ApplicationController

  skip_before_filter :check_xhr
  skip_before_filter :redirect_to_login_if_required

  before_filter :ensure_logged_in, only: [:destroy, :create, :check_csv_chunk, :upload_csv_chunk]

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
          redirect_to "#{Discourse.base_uri}#{topic.relative_url}"
          return
        end
      end
    end

    redirect_to "/"
  end

  def create
    params.require(:email)

    group_ids = Group.lookup_group_ids(params)

    guardian.ensure_can_invite_to_forum!(group_ids)

    if Invite.invite_by_email(params[:email], current_user, topic=nil,  group_ids)
      render json: success_json
    else
      render json: failed_json, status: 422
    end
  end

  def destroy
    params.require(:email)

    invite = Invite.find_by(invited_by_id: current_user.id, email: params[:email])
    raise Discourse::InvalidParameters.new(:email) if invite.blank?
    invite.trash!(current_user)

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

end
