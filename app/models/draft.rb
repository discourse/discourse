# frozen_string_literal: true

class Draft < ActiveRecord::Base
  NEW_TOPIC ||= 'new_topic'
  NEW_PRIVATE_MESSAGE ||= 'new_private_message'
  EXISTING_TOPIC ||= 'topic_'

  def self.set(user, key, sequence, data)
    if SiteSetting.backup_drafts_to_pm_length > 0 && SiteSetting.backup_drafts_to_pm_length < data.length
      backup_draft(user, key, sequence, data)
    end

    if d = find_draft(user, key)
      return if d.sequence > sequence

      DB.exec(<<~SQL, id: d.id, sequence: sequence, data: data)
        UPDATE drafts
           SET sequence = :sequence
             , data = :data
             , revisions = revisions + 1
         WHERE id = :id
      SQL
    else
      Draft.create!(user_id: user.id, draft_key: key, data: data, sequence: sequence)
    end

    true
  end

  def self.get(user, key, sequence)
    d = find_draft(user, key)
    d.data if d && d.sequence == sequence
  end

  def self.clear(user, key, sequence)
    d = find_draft(user, key)
    d.destroy if d && d.sequence <= sequence
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

    user_id = opts[:user].id
    offset = (opts[:offset] || 0).to_i
    limit = (opts[:limit] || 30).to_i

    # JOIN of topics table based on manipulating draft_key seems imperfect
    builder = DB.build <<~SQL
      SELECT
        d.*, t.title, t.id topic_id, t.archetype,
        t.category_id, t.closed topic_closed, t.archived topic_archived,
        pu.username, pu.name, pu.id user_id, pu.uploaded_avatar_id, pu.username_lower,
        du.username draft_username, NULL as raw, NULL as cooked, NULL as post_number
      FROM drafts d
      LEFT JOIN LATERAL json_extract_path_text (d.data::json, 'postId') postId ON TRUE
      LEFT JOIN posts p ON postId :: BIGINT = p.id
      LEFT JOIN topics t ON
        CASE
            WHEN d.draft_key LIKE '%' || '#{EXISTING_TOPIC}' || '%'
              THEN CAST(replace(d.draft_key, '#{EXISTING_TOPIC}', '') AS INT)
            ELSE 0
        END = t.id
      JOIN users pu on pu.id = COALESCE(p.user_id, t.user_id, d.user_id)
      JOIN users du on du.id = #{user_id}
      /*where*/
      /*order_by*/
      /*offset*/
      /*limit*/
    SQL

    builder
      .where('d.user_id = :user_id', user_id: user_id.to_i)
      .order_by('d.updated_at desc')
      .offset(offset)
      .limit(limit)
      .query
  end

  def self.cleanup!
    DB.exec(<<~SQL)
      DELETE FROM drafts
       WHERE sequence < (
        SELECT MAX(s.sequence)
          FROM draft_sequences s
         WHERE s.draft_key = drafts.draft_key
           AND s.user_id = drafts.user_id
      )
    SQL

    # remove old drafts
    delete_drafts_older_than_n_days = SiteSetting.delete_drafts_older_than_n_days.days.ago
    Draft.where("updated_at < ?", delete_drafts_older_than_n_days).destroy_all
  end

  def self.backup_draft(user, key, sequence, data)
    reply = JSON.parse(data)["reply"] || ""
    return if reply.length < SiteSetting.backup_drafts_to_pm_length

    post_id = BackupDraftPost.where(user_id: user.id, key: key).pluck(:post_id).first
    post = Post.where(id: post_id).first if post_id

    if post_id && !post
      BackupDraftPost.where(user_id: user.id, key: key).delete_all
    end

    indented_reply = reply.split("\n").map! do |l|
      "    #{l}"
    end
    draft_body = <<~MD
      #{indented_reply.join("\n")}

      ```text
      seq: #{sequence}
      key: #{key}
      ```
    MD

    return if post && post.raw == draft_body

    if !post
      topic = ensure_draft_topic!(user)
      Post.transaction do
        post = PostCreator.new(
          user,
          raw: draft_body,
          skip_jobs: true,
          skip_validations: true,
          topic_id: topic.id,
        ).create
        BackupDraftPost.create!(user_id: user.id, key: key, post_id: post.id)
      end
    elsif post.updated_at > 5.minutes.ago
      # bypass all validations here to maximize speed
      post.update_columns(
        raw: draft_body,
        cooked: PrettyText.cook(draft_body),
        updated_at: Time.zone.now
      )
    else
      revisor = PostRevisor.new(post, post.topic)
      revisor.revise!(user, { raw: draft_body },
        bypass_bump: true,
        skip_validations: true,
        skip_staff_log: true,
        bypass_rate_limiter: true
      )
    end

  rescue => e
    Discourse.warn_exception(e, message: "Failed to backup draft")
  end

  def self.ensure_draft_topic!(user)
    topic_id = BackupDraftTopic.where(user_id: user.id).pluck(:topic_id).first
    topic = Topic.find_by(id: topic_id) if topic_id

    if topic_id && !topic
      BackupDraftTopic.where(user_id: user.id).delete_all
    end

    if !topic
      Topic.transaction do
        creator = PostCreator.new(
          user,
          title: I18n.t("draft_backup.pm_title"),
          archetype: Archetype.private_message,
          raw: I18n.t("draft_backup.pm_body"),
          skip_jobs: true,
          skip_validations: true,
          target_usernames: user.username
        )
        topic = creator.create.topic
        BackupDraftTopic.create!(topic_id: topic.id, user_id: user.id)
      end
    end

    topic

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
