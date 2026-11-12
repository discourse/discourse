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
#  total_descendant_count         :integer          default(0), not null
#  whisper_direct_reply_count     :integer          default(0), not null
#  whisper_total_descendant_count :integer          default(0), not null
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  post_id                        :bigint           not null
#
# Indexes
#
#  index_nested_view_post_stats_on_post_id  (post_id) UNIQUE
#
