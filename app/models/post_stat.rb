# frozen_string_literal: true

class PostStat < ActiveRecord::Base
  COMPOSER_VERSIONS = { "1" => "classic", "2" => "rich_text" }

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
#  composer_version             :string
#  writing_device               :string
#  writing_device_user_agent    :string
#
# Indexes
#
#  index_post_stats_on_composer_version  (composer_version)
#  index_post_stats_on_post_id           (post_id)
#  index_post_stats_on_writing_device    (writing_device)
#
