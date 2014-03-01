class TopicRevision < ActiveRecord::Base
  belongs_to :topic
  belongs_to :user

  serialize :modifications, Hash
end

# == Schema Information
#
# Table name: topic_revisions
#
#  id            :integer          not null, primary key
#  user_id       :integer
#  topic_id      :integer
#  modifications :text
#  number        :integer
#  created_at    :datetime
#  updated_at    :datetime
#
# Indexes
#
#  index_topic_revisions_on_topic_id             (topic_id)
#  index_topic_revisions_on_topic_id_and_number  (topic_id,number)
#
