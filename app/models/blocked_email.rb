class BlockedEmail < ActiveRecord::Base

  before_validation :set_defaults

  validates :email, presence: true, uniqueness: true

  def self.actions
    @actions ||= Enum.new(:block, :do_nothing)
  end

  def self.should_block?(email)
    record = BlockedEmail.where(email: email).first
    if record
      record.match_count += 1
      record.last_match_at = Time.zone.now
      record.save
    end
    record && record.action_type == actions[:block]
  end

  def set_defaults
    self.action_type ||= BlockedEmail.actions[:block]
  end

end
