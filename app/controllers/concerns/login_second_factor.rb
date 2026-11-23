# frozen_string_literal: true

# Call after primary authentication and before issuing a session. If a factor is required,
# start! interrupts the login. Only the continuation may use the saved payload.
module LoginSecondFactor
  private

  def start_login_second_factor!(flow:, target_user:, callback_path:)
    return unless target_user.requires_second_factor_for_login?

    action =
      SecondFactor::Actions::Login.new(
        guardian,
        request,
        target_user:,
        opts: {
          flow:,
          callback_path:,
          payload: yield,
        },
      )
    manager = SecondFactor::AuthManager.new(guardian, action, target_user:)
    manager.allow_backup_codes!
    initiator = current_user
    if initiator && initiator != target_user
      # The next request must be anonymous, not authenticated as the previous account.
      log_off_user
      initiator = nil
    end
    manager.start!(request, server_session, initiator:)
  end

  def complete_login_second_factor!(flow:)
    nonce = params.require(:second_factor_nonce)
    challenge =
      SecondFactor::AuthManager.find_second_factor_challenge(
        nonce:,
        server_session:,
        request:,
        current_user:,
      )
    user = User.find(challenge.fetch(:target_user_id))
    action = SecondFactor::Actions::Login.new(guardian, request, target_user: user, opts: { flow: })
    manager = SecondFactor::AuthManager.new(guardian, action, target_user: user)
    [user, manager.complete!(challenge, server_session)]
  end
end
