class Draft < ActiveRecord::Base
  NEW_TOPIC = 'new_topic'
  NEW_PRIVATE_MESSAGE = 'new_private_message'
  EXISTING_TOPIC = 'topic_'

  def self.set(user, key, sequence, data)
    d = find_draft(user,key)
    if d
      return if d.sequence > sequence
      exec_sql("UPDATE drafts
               SET  data = :data,
                    sequence = :sequence,
                    revisions = revisions + 1
               WHERE id = :id", id: d.id, sequence: sequence, data: data)
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

  def self.find_draft(user, key)
    if user.is_a?(User)
      find_by(user_id: user.id, draft_key: key)
    else
      find_by(user_id: user, draft_key: key)
    end
  end

  def self.cleanup!
    exec_sql("DELETE FROM drafts where sequence < (
               SELECT max(s.sequence) from draft_sequences s
               WHERE s.draft_key = drafts.draft_key AND
                     s.user_id = drafts.user_id
            )")

    # remove old drafts
    delete_drafts_older_than_n_days = SiteSetting.delete_drafts_older_than_n_days.days.ago
    Draft.where("updated_at < ?", delete_drafts_older_than_n_days).destroy_all
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
#  revisions  :integer          default(1), not null
#
# Indexes
#
#  index_drafts_on_user_id_and_draft_key  (user_id,draft_key)
#
