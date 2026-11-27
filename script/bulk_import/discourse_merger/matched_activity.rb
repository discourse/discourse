# frozen_string_literal: true

module BulkImport::DiscourseMerge
  class MatchedActivity
    def self.visit_dates_present?(source, members)
      return true if members.empty?
      ids = members.keys.map { |id| Integer(id) }.join(",")
      query = "SELECT user_id, visited_at FROM user_visits WHERE user_id IN (#{ids})"
      SourceRows.each_batch(source, query) do |rows|
        required =
          rows
            .map do |row|
              [members.fetch(Integer(row.fetch("user_id"))), Date.iso8601(row.fetch("visited_at"))]
            end
            .uniq
        unless UserVisit.where(%i[user_id visited_at] => required).count == required.size
          return false
        end
      end
      true
    end

    def initialize(source, members, audit)
      @source, @members, @audit = source, members, audit
    end

    def apply!
      @matched_summaries = {}
      return @matched_summaries if @members.empty?
      query = <<~SQL
        SELECT user_id, visited_at, posts_read, mobile, time_read
        FROM user_visits WHERE user_id IN (#{@members.keys.map { |id| Integer(id) }.join(",")}) ORDER BY user_id, visited_at
      SQL
      UserVisit.transaction do
        SourceRows.each_batch(@source, query) do |batch|
          rows =
            batch.map do |row|
              row.merge("user_id" => @members.fetch(Integer(row.fetch("user_id"))))
            end
          merge_visit_rows(rows)
        end
        refresh_matched_summaries(@members.values.uniq)
      end
      @matched_summaries
    end

    private

    def merge_visit_rows(rows)
      visits = rows.group_by { |row| [row.fetch("user_id"), row.fetch("visited_at")] }
      records =
        visits.map do |(user_id, day), history|
          {
            user_id: user_id,
            visited_at: day,
            time_read: history.sum { |row| row.fetch("time_read").to_i },
            posts_read: history.sum { |row| row.fetch("posts_read").to_i },
            mobile:
              history.any? { |row| UserVisit.type_for_attribute("mobile").cast(row["mobile"]) },
          }
        end
      UserVisit.upsert_all(
        records,
        unique_by: %i[user_id visited_at],
        on_duplicate: Arel.sql(<<~SQL),
          time_read = user_visits.time_read + EXCLUDED.time_read,
          posts_read = COALESCE(user_visits.posts_read, 0) + EXCLUDED.posts_read,
          mobile = COALESCE(user_visits.mobile, false) OR EXCLUDED.mobile
        SQL
      )
    end

    def refresh_matched_summaries(user_ids)
      user_ids.each_slice(500) do |ids|
        visits = UserVisit.where(user_id: ids).group(:user_id)
        evidence = {
          days_visited: visits.count,
          time_read: visits.sum(:time_read),
          topics_entered: TopicViewItem.where(user_id: ids).group(:user_id).count,
          posts_read_count:
            PostTiming
              .where(
                user_id: ids,
                topic_id: Topic.where(archetype: "regular", deleted_at: nil).select(:id),
              )
              .group(:user_id)
              .count,
        }
        stats = UserStat.where(user_id: ids).index_by(&:user_id)
        ids.each do |id|
          stat = stats[id] || UserStat.create!(user_id: id, new_since: Time.current)
          evidence.each do |field, counts|
            derived = counts.fetch(id, 0)
            stored = stat[field].to_i
            if derived < stored
              @audit << {
                event: "summary_value_preserved",
                user_id: id,
                field: field,
                stored: stored,
                derived: derived,
              }
            else
              stat[field] = derived
            end
          end
          values = evidence.keys.index_with { |field| stat[field] }
          stat.update_columns(values) if stat.changed?
          @matched_summaries[id] = values
        end
      end
    end
  end
end
