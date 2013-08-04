class BlockedEmail < ActiveRecord::Base

  before_validation :set_defaults

  validates :email, presence: true, uniqueness: true

  def self.actions
    @actions ||= Enum.new(:block, :do_nothing)
  end

  def self.block(email, opts={})
    find_by_email(email) || create(opts.slice(:action_type).merge({email: email}))
  end

  def self.should_block?(email)
    blocked_email = BlockedEmail.where(email: email).first
    blocked_email.record_match! if blocked_email
    blocked_email && blocked_email.action_type == actions[:block]
  end

  def set_defaults
    self.action_type ||= BlockedEmail.actions[:block]
  end

  def record_match!
    self.match_count += 1
    self.last_match_at = Time.zone.now
    save
  end

end
