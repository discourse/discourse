class InvitesController < ApplicationController

  skip_before_filter :check_xhr, :check_restricted_access
  before_filter :ensure_logged_in, only: [:destroy]

  def show
    invite = Invite.where(invite_key: params[:id]).first

    if invite.present?
      user = invite.redeem
      if user.present?
        log_on_user(user)

        # Send a welcome message if required
        user.enqueue_welcome_message('welcome_invite') if user.send_welcome_message

        # We skip the access password if we come in via an invite link
        cookies.permanent['_access'] = SiteSetting.access_password if SiteSetting.access_password.present?

        topic = invite.topics.first
        if topic.present?
          redirect_to "#{Discourse.base_uri}#{topic.relative_url}"
          return
        end
      end
    end

    redirect_to root_path
  end

  def destroy
    requires_parameter(:email)

    invite = Invite.where(invited_by_id: current_user.id, email: params[:email]).first
    raise Discourse::InvalidParameters.new(:email) if invite.blank?
    invite.destroy

    render nothing: true
  end

end
