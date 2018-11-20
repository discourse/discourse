class SharedDraft < ActiveRecord::Base
  belongs_to :topic
  belongs_to :category
end

# == Schema Information
#
# Table name: shared_drafts
#
#  topic_id    :integer          not null
#  category_id :integer          not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  id          :bigint(8)        not null, primary key
#
# Indexes
#
#  index_shared_drafts_on_category_id  (category_id)
#  index_shared_drafts_on_topic_id     (topic_id) UNIQUE
#
