# frozen_string_literal: true

# Per-address bounce state, keyed case-insensitively. Every write goes through
# the class methods below rather than through Active Record, so that concurrent
# bounces for the same address can't lose an update.
class EmailBounceScore < ActiveRecord::Base
  def self.canonicalize(email)
    Email.downcase(email.to_s.strip)
  end

  def self.for_email(email)
    where(email: canonicalize(email))
  end

  def self.for_user(user)
    where(email: user.user_emails.select("lower(user_emails.email)"))
  end

  def self.record_bounce!(email, score)
    email = canonicalize(email)
    return if !Email.is_valid?(email)

    DB.exec(
      <<~SQL,
      INSERT INTO email_bounce_scores
        (email, bounce_score, reset_bounce_score_after, created_at, updated_at)
      VALUES
        (:email, :score, :reset_after, :now, :now)
      ON CONFLICT (email)
      DO UPDATE SET
        bounce_score = email_bounce_scores.bounce_score + EXCLUDED.bounce_score,
        reset_bounce_score_after = EXCLUDED.reset_bounce_score_after,
        updated_at = EXCLUDED.updated_at
    SQL
      email:,
      score:,
      reset_after: SiteSetting.reset_bounce_score_after_days.days.from_now,
      now: Time.zone.now,
    )
  end

  def self.erode!(email, amount)
    return if amount <= 0

    for_email(email).where("bounce_score > 0").update_all(
      ["bounce_score = GREATEST(bounce_score - ?, 0), updated_at = ?", amount, Time.zone.now],
    )
  end

  def self.reset!(email)
    for_email(email).delete_all
  end

  def self.score_for(email)
    for_email(email).pick(:bounce_score).to_f
  end

  # rows only matter while an address is in bad standing, so drop the ones that
  # have eroded away or whose window has run out
  def self.ensure_consistency!
    where("reset_bounce_score_after < now() OR bounce_score <= 0").delete_all
  end
end

# == Schema Information
#
# Table name: email_bounce_scores
#
#  id                       :bigint           not null, primary key
#  bounce_score             :float            default(0.0), not null
#  email                    :string(513)      not null
#  reset_bounce_score_after :datetime         not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#
# Indexes
#
#  index_email_bounce_scores_on_email  (email) UNIQUE
#
