class AdminConfirmation
  attr_accessor :token
  attr_reader :performed_by
  attr_reader :target_user

  def initialize(target_user, performed_by)
    @target_user = target_user
    @performed_by = performed_by
  end

  def create_confirmation
    guardian = Guardian.new(@performed_by)
    guardian.ensure_can_grant_admin!(@target_user)

    @token = SecureRandom.hex
    $redis.setex("admin-confirmation:#{@target_user.id}", 3.hours.to_i, @token)

    payload = {
      target_user_id: @target_user.id,
      performed_by: @performed_by.id
    }
    $redis.setex("admin-confirmation-token:#{@token}", 3.hours.to_i, payload.to_json)

    Jobs.enqueue(
      :admin_confirmation_email,
      to_address: @performed_by.email,
      target_username: @target_user.username,
      token: @token
    )
  end

  def email_confirmed!
    guardian = Guardian.new(@performed_by)
    guardian.ensure_can_grant_admin!(@target_user)

    @target_user.grant_admin!
    StaffActionLogger.new(@performed_by).log_grant_admin(@target_user)
    $redis.del "admin-confirmation:#{@target_user.id}"
    $redis.del "admin-confirmation-token:#{@token}"
  end

  def self.exists_for?(user_id)
    $redis.exists "admin-confirmation:#{user_id}"
  end

  def self.find_by_code(token)
    json = $redis.get("admin-confirmation-token:#{token}")
    return nil unless json

    parsed = JSON.parse(json)
    target_user = User.find(parsed['target_user_id'].to_i)
    performed_by = User.find(parsed['performed_by'].to_i)

    ac = AdminConfirmation.new(target_user, performed_by)
    ac.token = token
    ac
  end

end
