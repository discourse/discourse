class PostStat < ActiveRecord::Base
  belongs_to :post
end

# == Schema Information
#
# Table name: post_stats
#
#  id                           :integer          not null, primary key
#  post_id                      :integer
#  drafts_saved                 :integer
#  typing_duration_msecs        :integer
#  composer_open_duration_msecs :integer
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#
# Indexes
#
#  index_post_stats_on_post_id  (post_id)
#
