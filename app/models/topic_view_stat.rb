# frozen_string_literal: true

class TopicViewStat < ActiveRecord::Base
  belongs_to :topic

  def self.add(topic_id:, date:, anonymous_views:, logged_in_views:)
    sql = <<~SQL
          INSERT INTO topic_view_stats (topic_id, viewed_at, anonymous_views, logged_in_views)
          VALUES (:topic_id, :viewed_at, :anon_views, :logged_in_views)
          ON CONFLICT (topic_id, viewed_at)
          DO UPDATE SET
            anonymous_views = topic_view_stats.anonymous_views + :anon_views,
            logged_in_views = topic_view_stats.logged_in_views + :logged_in_views
        SQL

    DB.exec(
      sql,
      topic_id: topic_id,
      viewed_at: date,
      anon_views: anonymous_views,
      logged_in_views: logged_in_views,
    )
  end
end

# == Schema Information
#
# Table name: topic_view_stats
#
#  id              :bigint           not null, primary key
#  topic_id        :integer          not null
#  viewed_at       :date             not null
#  anonymous_views :integer          default(0), not null
#  logged_in_views :integer          default(0), not null
#
# Indexes
#
#  index_topic_view_stats_on_topic_id_and_viewed_at  (topic_id,viewed_at) UNIQUE
#  index_topic_view_stats_on_viewed_at_and_topic_id  (viewed_at,topic_id)
#
