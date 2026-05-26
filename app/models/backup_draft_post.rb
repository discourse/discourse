# frozen_string_literal: true

class BackupDraftPost < ActiveRecord::Base
  belongs_to :user
  belongs_to :post
end

# == Schema Information
#
# Table name: backup_draft_posts
#
#  id         :bigint           not null, primary key
#  key        :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  post_id    :integer          not null
#  user_id    :integer          not null
#
# Indexes
#
#  index_backup_draft_posts_on_post_id          (post_id) UNIQUE
#  index_backup_draft_posts_on_user_id_and_key  (user_id,key) UNIQUE
#
