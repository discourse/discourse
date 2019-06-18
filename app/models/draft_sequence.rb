# frozen_string_literal: true

class DraftSequence < ActiveRecord::Base
  def self.next!(user, key)
    user_id = user
    user_id = user.id unless user.is_a?(Integer)

    return 0 if user_id < 0

    h = { user_id: user_id, draft_key: key }
    c = DraftSequence.find_by(h)
    c ||= DraftSequence.new(h)
    c.sequence ||= 0
    c.sequence += 1
    c.save!
    DB.exec("DELETE FROM drafts WHERE user_id = :user_id AND draft_key = :draft_key AND sequence < :sequence", draft_key: key, user_id: user_id, sequence: c.sequence)
    c.sequence
  end

  def self.current(user, key)
    return nil unless user

    user_id = user
    user_id = user.id unless user.is_a?(Integer)

    # perf critical path
    r, _ = DB.query_single('select sequence from draft_sequences where user_id = ? and draft_key = ?', user_id, key)
    r.to_i
  end
end

# == Schema Information
#
# Table name: draft_sequences
#
#  id        :integer          not null, primary key
#  user_id   :integer          not null
#  draft_key :string           not null
#  sequence  :integer          not null
#
# Indexes
#
#  index_draft_sequences_on_user_id_and_draft_key  (user_id,draft_key) UNIQUE
#
