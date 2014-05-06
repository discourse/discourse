class InvitesController < ApplicationController

  skip_before_filter :check_xhr
  skip_before_filter :redirect_to_login_if_required

  before_filter :ensure_logged_in, only: [:destroy, :create]

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

    guardian.ensure_can_invite_to_forum!

    if Invite.invite_by_email(params[:email], current_user)
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

end
