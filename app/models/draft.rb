class Draft < ActiveRecord::Base
  NEW_TOPIC = 'new_topic'
  NEW_PRIVATE_MESSAGE = 'new_private_message'
  EXISTING_TOPIC = 'topic_'

  def self.set(user, key, sequence, data)
    d = find_draft(user,key)
    if d
      return if d.sequence > sequence
      d.data = data
      d.sequence = sequence
    else
      d = Draft.new(user_id: user.id, draft_key: key, data: data, sequence: sequence)
    end
    d.save!
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
