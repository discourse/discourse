class DraftSequence < ActiveRecord::Base
  def self.next!(user,key)
    user_id = user
    user_id = user.id unless user.class == Fixnum
    h = { user_id: user_id, draft_key: key }
    c = DraftSequence.where(h).first
    c ||= DraftSequence.new(h)
    c.sequence ||= 0
    c.sequence += 1
    c.save
    c.sequence
  end

  def self.current(user, key)
    return nil unless user

    user_id = user
    user_id = user.id unless user.class == Fixnum

    # perf critical path
    r = exec_sql('select sequence from draft_sequences where user_id = ? and draft_key = ?', user_id, key).values

    r.length.zero? ? 0 : r[0][0].to_i
  end
end

# == Schema Information
#
# Table name: draft_sequences
#
#  id        :integer          not null, primary key
#  user_id   :integer          not null
#  draft_key :string(255)      not null
#  sequence  :integer          not null
#
# Indexes
#
#  index_draft_sequences_on_user_id_and_draft_key  (user_id,draft_key) UNIQUE
#

