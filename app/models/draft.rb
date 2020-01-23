# frozen_string_literal: true

class Draft < ActiveRecord::Base
  NEW_TOPIC ||= 'new_topic'
  NEW_PRIVATE_MESSAGE ||= 'new_private_message'
  EXISTING_TOPIC ||= 'topic_'

  class OutOfSequence < StandardError; end

  def self.set(user, key, sequence, data, owner = nil, retry_not_unique: true)
    if SiteSetting.backup_drafts_to_pm_length > 0 && SiteSetting.backup_drafts_to_pm_length < data.length
      backup_draft(user, key, sequence, data)
    end

    # this is called a lot so we should micro optimize here
    draft_id, current_owner, current_sequence = DB.query_single(<<~SQL, user_id: user.id, key: key)
      WITH draft AS (
        SELECT id, owner FROM drafts
        WHERE
          user_id = :user_id AND
          draft_key = :key
      ),
      draft_sequence AS (
        SELECT sequence
        FROM draft_sequences
        WHERE
          user_id = :user_id AND
          draft_key = :key
      )

      SELECT
        (SELECT id FROM draft),
        (SELECT owner FROM draft),
        (SELECT sequence FROM draft_sequence)
    SQL

    current_sequence ||= 0

    if draft_id
      if current_sequence != sequence
        raise Draft::OutOfSequence
      end

      if owner && current_owner && current_owner != owner
        sequence += 1

        DraftSequence.upsert({
            sequence: sequence,
            draft_key: key,
            user_id: user.id,
          },
          unique_by: [:user_id, :draft_key]
        )
      end

      DB.exec(<<~SQL, id: draft_id, sequence: sequence, data: data, owner: owner || current_owner)
        UPDATE drafts
           SET sequence = :sequence
             , data = :data
             , revisions = revisions + 1
             , owner = :owner
         WHERE id = :id
      SQL

    elsif sequence != current_sequence
      raise Draft::OutOfSequence
    else
      begin
        Draft.create!(
          user_id: user.id,
          draft_key: key,
          data: data,
          sequence: sequence,
          owner: owner
        )
      rescue ActiveRecord::RecordNotUnique => e
        # we need this to be fast and with minimal locking, in some cases we can have a race condition
        # around 2 controller actions calling for draft creation at the exact same time
        # to avoid complex locking and a distributed mutex, since this is so rare, simply add a single retry
        if retry_not_unique
          set(user, key, sequence, data, owenr, retry_not_unique: false)
        else
          raise e
        end
      end
    end

    sequence
  end

  def self.get(user, key, sequence)

    opts = {
      user_id: user.id,
      draft_key: key,
      sequence: sequence
    }

    current_sequence, data, draft_sequence = DB.query_single(<<~SQL, opts)
      WITH draft AS (
        SELECT data, sequence
        FROM drafts
        WHERE draft_key = :draft_key AND user_id = :user_id
      ),
      draft_sequence AS (
        SELECT sequence
        FROM draft_sequences
        WHERE draft_key = :draft_key AND user_id = :user_id
      )
      SELECT
        ( SELECT sequence FROM draft_sequence) ,
        ( SELECT data FROM draft ),
        ( SELECT sequence FROM draft )
    SQL

    current_sequence ||= 0

    if sequence != current_sequence
      raise Draft::OutOfSequence
    end

    data if current_sequence == draft_sequence
  end

  def self.clear(user, key, sequence)
    current_sequence = DraftSequence.current(user, key)

    # bad caller is a reason to complain
    if sequence != current_sequence
      raise Draft::OutOfSequence
    end

    # corrupt data is not a reason not to leave data
    Draft.where(user_id: user.id, draft_key: key).destroy_all
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

    post_id = BackupDraftPost.where(user_id: user.id, key: key).pluck_first(:post_id)
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
    elsif post.last_version_at > 5.minutes.ago
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
    topic_id = BackupDraftTopic.where(user_id: user.id).pluck_first(:topic_id)
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
#  owner      :string
#
# Indexes
#
#  index_drafts_on_user_id_and_draft_key  (user_id,draft_key) UNIQUE
#
