# frozen_string_literal: true

class PostStat < ActiveRecord::Base
  # Version 1 is the original textarea composer for Discourse,
  # which has been around since its inception and uses a split
  # pane between markdown and preview.
  #
  # Version 2 is the new rich text composer, which is a single
  # contendedibale using ProseMirror which is more of a WYSIWYG
  # experience.
  COMPOSER_VERSIONS = { 1 => "classic", 2 => "rich_text" }

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
#  composer_version             :integer
#  writing_device               :string
#  writing_device_user_agent    :string
#
# Indexes
#
#  index_post_stats_on_composer_version  (composer_version)
#  index_post_stats_on_post_id           (post_id)
#  index_post_stats_on_writing_device    (writing_device)
#
