# frozen_string_literal: true

module DiscourseRssPolling
  class PollAttempt < ActiveRecord::Base
    self.table_name = "discourse_rss_polling_poll_attempts"

    belongs_to :rss_feed, class_name: "DiscourseRssPolling::RssFeed"

    enum :status, { success: 0, error: 1 }

    KEEP_PER_FEED = 20
    MAX_ITEMS = 50

    scope :recent, -> { order(created_at: :desc, id: :desc) }

    def self.record!(rss_feed_id:, items:, error: nil)
      counts = items.map { |item| item["status"] }.tally
      failed_count = counts.fetch("failed", 0)

      attempt =
        create!(
          rss_feed_id:,
          status: (error || failed_count.positive?) ? :error : :success,
          imported_count: counts.fetch("imported", 0),
          updated_count: counts.fetch("updated", 0),
          skipped_count: counts.fetch("skipped", 0),
          failed_count:,
          error:,
          items: items.first(MAX_ITEMS),
        )
      purge_old(rss_feed_id)
      attempt
    end

    def self.purge_old(rss_feed_id)
      old_ids = where(rss_feed_id:).recent.offset(KEEP_PER_FEED).pluck(:id)
      where(id: old_ids).delete_all if old_ids.present?
    end
  end
end

# == Schema Information
#
# Table name: discourse_rss_polling_poll_attempts
#
#  id             :bigint           not null, primary key
#  error          :text
#  failed_count   :integer          default(0), not null
#  imported_count :integer          default(0), not null
#  items          :jsonb            not null
#  skipped_count  :integer          default(0), not null
#  status         :integer          default("success"), not null
#  updated_count  :integer          default(0), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  rss_feed_id    :bigint           not null
#
# Indexes
#
#  idx_rss_polling_poll_attempts_on_feed_created_id_desc  (rss_feed_id,created_at DESC,id DESC)
#
