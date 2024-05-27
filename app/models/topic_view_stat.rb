# frozen_string_literal: true

class TopicViewStat < ActiveRecord::Base
  belongs_to :topic
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
