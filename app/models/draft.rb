class Draft < ActiveRecord::Base
  NEW_TOPIC = 'new_topic'
  NEW_PRIVATE_MESSAGE = 'new_private_message'
  EXISTING_TOPIC = 'topic_'

  def self.set(user, key, sequence, data)
    d = find_draft(user,key)
    if d
      return if d.sequence > sequence
      d.update_columns(data: data, sequence: sequence)
    else
      Draft.create!(user_id: user.id, draft_key: key, data: data, sequence: sequence)
    end
  end

  def self.get(user, key, sequence)
    d = find_draft(user,key)
    if d && d.sequence == sequence
      d.data
    end
  end

  def self.clear(user, key, sequence)
    d = find_draft(user,key)
    if d && d.sequence <= sequence
      d.destroy
    end
  end

  protected

  def self.find_draft(user,key)
    user_id = user
    user_id = user.id if User === user
    Draft.where(user_id: user_id, draft_key: key).first
  end
end

# == Schema Information
#
# Table name: drafts
#
#  id         :integer          not null, primary key
#  user_id    :integer          not null
#  draft_key  :string(255)      not null
#  data       :text             not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  sequence   :integer          default(0), not null
#
# Indexes
#
#  index_drafts_on_user_id_and_draft_key  (user_id,draft_key)
#

