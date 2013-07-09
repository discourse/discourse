class InvitesController < ApplicationController

  skip_before_filter :check_xhr
  skip_before_filter :redirect_to_login_if_required

  before_filter :ensure_logged_in, only: [:destroy]

  def show
    invite = Invite.where(invite_key: params[:id]).first

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

  def destroy
    params.require(:email)

    invite = Invite.where(invited_by_id: current_user.id, email: params[:email]).first
    raise Discourse::InvalidParameters.new(:email) if invite.blank?
    invite.trash!(current_user)

    render nothing: true
  end

end
