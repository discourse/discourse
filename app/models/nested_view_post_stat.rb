# frozen_string_literal: true

class NestedViewPostStat < ActiveRecord::Base
  belongs_to :post
end

# == Schema Information
#
# Table name: nested_view_post_stats
#
#  id                             :bigint           not null, primary key
#  direct_reply_count             :integer          default(0), not null
#  hot_score                      :float            default(0.0), not null
#  hot_score_updated_at           :datetime
#  post_number                    :integer
#  relative_hot_score             :float            default(0.0), not null
#  relative_thread_hot_score      :float            default(0.0), not null
#  reply_to_post_number           :integer
#  thread_hot_score               :float            default(0.0), not null
#  total_descendant_count         :integer          default(0), not null
#  whisper_direct_reply_count     :integer          default(0), not null
#  whisper_total_descendant_count :integer          default(0), not null
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  post_id                        :bigint           not null
#  topic_id                       :bigint
#
# Indexes
#
#  idx_nested_stats_hot_siblings            (topic_id,reply_to_post_number,thread_hot_score DESC,hot_score DESC,post_number)
#  index_nested_view_post_stats_on_post_id  (post_id) UNIQUE
#
