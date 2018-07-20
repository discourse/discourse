# frozen_string_literal: true

class Draft < ActiveRecord::Base
  NEW_TOPIC = 'new_topic'
  NEW_PRIVATE_MESSAGE = 'new_private_message'
  EXISTING_TOPIC = 'topic_'

  def self.set(user, key, sequence, data)
    d = find_draft(user, key)
    if d
      return if d.sequence > sequence
      DB.exec("UPDATE drafts
               SET  data = :data,
                    sequence = :sequence,
                    revisions = revisions + 1
               WHERE id = :id", id: d.id, sequence: sequence, data: data)
    else
      Draft.create!(user_id: user.id, draft_key: key, data: data, sequence: sequence)
    end

    true
  end

  def self.get(user, key, sequence)
    d = find_draft(user, key)
    if d && d.sequence == sequence
      d.data
    end
  end

  def self.clear(user, key, sequence)
    d = find_draft(user, key)
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

  def self.stream(opts = nil)
    opts ||= {}

    user_id = opts[:user_id]
    offset = opts[:offset] || 0
    limit = opts[:limit] || 30

    # JOIN of topics table based on manipulating draft_key seems imperfect
    builder = DB.build <<~SQL
      SELECT
        d.*, t.title, t.id topic_id,
        t.category_id, t.closed topic_closed, t.archived topic_archived,
        pu.username, pu.name, pu.id user_id, pu.uploaded_avatar_id,
        du.username draft_username
      FROM drafts d
      LEFT JOIN topics t ON
        CASE
            WHEN d.draft_key = '#{NEW_TOPIC}' THEN 0
            WHEN d.draft_key = '#{NEW_PRIVATE_MESSAGE}' THEN 0
            ELSE CAST(replace(d.draft_key, '#{EXISTING_TOPIC}', '') AS INT)
        END = t.id
      LEFT JOIN categories c on c.id = t.category_id
      JOIN users pu on pu.id = COALESCE(t.user_id, d.user_id)
      JOIN users du on du.id = #{user_id}
      /*where*/
      /*order_by*/
      /*offset*/
      /*limit*/
    SQL

    builder
      .where('d.user_id = :user_id', user_id: user_id.to_i)
      .order_by('d.updated_at desc')
      .offset(offset.to_i)
      .limit(limit.to_i)
      .query
  end

  def self.cleanup!
    DB.exec("DELETE FROM drafts where sequence < (
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
#  draft_key  :string           not null
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
