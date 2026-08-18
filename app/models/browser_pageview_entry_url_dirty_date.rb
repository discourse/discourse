# frozen_string_literal: true

require "zlib"

class BrowserPageviewEntryUrlDirtyDate < ActiveRecord::Base
  BUCKET_COUNT = 256

  def self.mark!(events)
    entries =
      Array(events)
        .filter_map do |date, session_id|
          [date.to_date, Zlib.crc32(session_id.to_s) % BUCKET_COUNT] if date && session_id.present?
        end
        .uniq
        .sort
    return if entries.empty?

    DB.exec(<<~SQL, dates: entries.map(&:first), buckets: entries.map(&:second))
      INSERT INTO browser_pageview_entry_url_dirty_dates (date, bucket, generation)
      SELECT date, bucket, 1
      FROM unnest(
        ARRAY[:dates]::date[],
        ARRAY[:buckets]::integer[]
      ) AS dirty(date, bucket)
      ON CONFLICT (date, bucket) DO UPDATE
      SET generation = browser_pageview_entry_url_dirty_dates.generation + 1
    SQL
  end

  def self.snapshot
    order(:date, :bucket).pluck(:date, :bucket, :generation)
  end

  def self.clear!(snapshot)
    return if snapshot.empty?

    DB.exec(
      <<~SQL,
        DELETE FROM browser_pageview_entry_url_dirty_dates dirty_dates
        USING unnest(
          ARRAY[:dates]::date[],
          ARRAY[:buckets]::integer[],
          ARRAY[:generations]::bigint[]
        ) AS processed(date, bucket, generation)
        WHERE dirty_dates.date = processed.date
          AND dirty_dates.bucket = processed.bucket
          AND dirty_dates.generation = processed.generation
      SQL
      dates: snapshot.map(&:first),
      buckets: snapshot.map(&:second),
      generations: snapshot.map(&:third),
    )
  end
end

# == Schema Information
#
# Table name: browser_pageview_entry_url_dirty_dates
#
#  id         :bigint           not null, primary key
#  bucket     :integer          not null
#  date       :date             not null
#  generation :bigint           default(1), not null
#
# Indexes
#
#  idx_bpeu_dirty_dates_unique  (date,bucket) UNIQUE
#
