# frozen_string_literal: true

class GroupMention < ActiveRecord::Base
  belongs_to :post
  belongs_to :group
end

# == Schema Information
#
# Table name: group_mentions
#
#  id         :integer          not null, primary key
#  post_id    :integer
#  group_id   :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_group_mentions_on_group_id_and_post_id  (group_id,post_id) UNIQUE
#  index_group_mentions_on_post_id_and_group_id  (post_id,group_id) UNIQUE
#
