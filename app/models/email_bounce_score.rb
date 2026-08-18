# frozen_string_literal: true

# Per-address bounce state, keyed case-insensitively. Every write goes through
# the class methods below rather than through Active Record, so that concurrent
# bounces for the same address can't lose an update.
#
# This table decides whether an address may be emailed. `user_stats.bounce_score`
# and `user_stats.reset_bounce_score_after` are a derived mirror of the row for
# the user's current primary address, kept for the admin API and for reporting.
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

  def self.deliverable?(email)
    score_for(email) < SiteSetting.bounce_score_threshold
  end

  # An address is in this table only while it is in bad standing, so membership
  # has to be tested with an anti-join: joining the table in would drop every
  # address that has never bounced. Correlates against `user_emails`, which the
  # caller is expected to have joined already.
  def self.deliverable_sql
    sql = <<~SQL
      NOT EXISTS (
        SELECT 1
        FROM email_bounce_scores
        WHERE email_bounce_scores.email = lower(user_emails.email)
          AND email_bounce_scores.bounce_score >= ?
      )
    SQL

    sanitize_sql_array([sql, SiteSetting.bounce_score_threshold])
  end

  # Returns the row as it stands after the bounce, or nil for an address we
  # could never have sent to. The upsert either inserts `score` or adds it, so
  # the score before this bounce is always `bounce_score - score`.
  def self.record_bounce!(email, score)
    email = canonicalize(email)
    return if !Email.is_valid?(email)

    recorded =
      DB.query(
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
        RETURNING bounce_score, reset_bounce_score_after
      SQL
        email:,
        score:,
        reset_after: SiteSetting.reset_bounce_score_after_days.days.from_now,
        now: Time.zone.now,
      ).first

    sync_user_stat!(email)
    recorded
  end

  def self.erode!(email, amount)
    return if amount <= 0

    eroded =
      for_email(email).where("bounce_score > 0").update_all(
        ["bounce_score = GREATEST(bounce_score - ?, 0), updated_at = ?", amount, Time.zone.now],
      )

    sync_user_stat!(email) if eroded > 0
  end

  def self.reset!(email)
    sync_user_stat!(email) if for_email(email).delete_all > 0
  end

  def self.reset_for_user!(user)
    for_user(user).delete_all
    UserStat.refresh_bounce_score(user.id)
  end

  def self.score_for(email)
    for_email(email).pick(:bounce_score).to_f
  end

  # `user_stats` mirrors the ledger row of the user's primary address, so a
  # write here has to tell whoever owns this one as theirs.
  def self.sync_user_stat!(email)
    UserStat.refresh_bounce_score(User.with_primary_email(canonicalize(email)).pick(:id))
  end

  # Rows only matter while an address is in bad standing, so drop the ones that
  # have eroded away or whose window has run out
  def self.ensure_consistency!
    where("reset_bounce_score_after < now() OR bounce_score <= 0").delete_all
    # here rather than in `UserStat.ensure_consistency!` so it runs after the
    # rows it has to account for are gone
    UserStat.refresh_bounce_scores!
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
