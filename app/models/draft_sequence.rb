# frozen_string_literal: true

class DraftSequence < ActiveRecord::Base
  def self.next!(user, key)
    return nil if !user

    user_id = user
    user_id = user.id unless user.is_a?(Integer)

    return 0 if !User.human_user_id?(user_id)

    sequence = DB.query_single(<<~SQL, user_id: user_id, draft_key: key).first
        INSERT INTO draft_sequences (user_id, draft_key, sequence)
        VALUES (:user_id, :draft_key, 1)
        ON CONFLICT (user_id, draft_key) DO
        UPDATE
        SET sequence = draft_sequences.sequence + 1
        WHERE draft_sequences.user_id = :user_id
        AND draft_sequences.draft_key = :draft_key
        RETURNING sequence
      SQL

    Draft.where(user_id: user_id).where(draft_key: key).where("sequence < ?", sequence).destroy_all

    UserStat.update_draft_count(user_id)

    sequence
  end

  def self.current(user, key)
    return nil if !user

    user_id = user
    user_id = user.id unless user.is_a?(Integer)

    return 0 if !User.human_user_id?(user_id)

    # perf critical path
    r, _ =
      DB.query_single(
        "select sequence from draft_sequences where user_id = ? and draft_key = ?",
        user_id,
        key,
      )
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
#  sequence  :bigint           not null
#
# Indexes
#
#  index_draft_sequences_on_user_id_and_draft_key  (user_id,draft_key) UNIQUE
#
