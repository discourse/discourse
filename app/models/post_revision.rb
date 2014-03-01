class PostRevision < ActiveRecord::Base
  belongs_to :post
  belongs_to :user

  serialize :modifications, Hash
end

# == Schema Information
#
# Table name: post_revisions
#
#  id            :integer          not null, primary key
#  user_id       :integer
#  post_id       :integer
#  modifications :text
#  number        :integer
#  created_at    :datetime
#  updated_at    :datetime
#
# Indexes
#
#  index_post_revisions_on_post_id             (post_id)
#  index_post_revisions_on_post_id_and_number  (post_id,number)
#
