# frozen_string_literal: true

class Draft < ActiveRecord::Base
  NEW_TOPIC = "new_topic"
  NEW_PRIVATE_MESSAGE = "new_private_message"
  EXISTING_TOPIC = "topic_"

  belongs_to :user

  has_many :upload_references, as: :target, dependent: :delete_all

  validates :draft_key, length: { maximum: 40 }

  after_commit :update_draft_count, on: %i[create destroy]

  scope :live, -> { where(deleted_at: nil) }
  scope :discarded, -> { where.not(deleted_at: nil) }

  class OutOfSequence < StandardError
  end

  class RestoreConflict < StandardError
  end

  def self.set(user, key, sequence, data, owner = nil, force_save: false)
    return 0 if !User.human_user_id?(user.id)
    force_save = force_save.to_s == "true"

    if SiteSetting.backup_drafts_to_pm_length > 0 &&
         SiteSetting.backup_drafts_to_pm_length < data.length
      backup_draft(user, key, sequence, data)
    end

    # this is called a lot so we should micro optimize here
    draft_id, current_owner, current_sequence = DB.query_single(<<~SQL, user_id: user.id, key: key)
      WITH draft AS (
        SELECT id, owner FROM drafts
        WHERE
          user_id = :user_id AND
          draft_key = :key AND
          deleted_at IS NULL
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
      raise Draft::OutOfSequence if !force_save && (current_sequence != sequence)

      sequence = current_sequence if force_save
      sequence += 1

      # we need to keep upping our sequence on every save
      # if we do not do that there are bad race conditions
      DraftSequence.upsert(
        { sequence: sequence, draft_key: key, user_id: user.id },
        unique_by: %i[user_id draft_key],
      )

      DB.exec(<<~SQL, id: draft_id, sequence: sequence, data: data, owner: owner || current_owner)
        UPDATE drafts
           SET sequence = :sequence
             , data = :data
             , revisions = revisions + 1
             , owner = :owner
             , updated_at = CURRENT_TIMESTAMP
         WHERE id = :id
      SQL
    elsif sequence != current_sequence
      raise Draft::OutOfSequence
    else
      opts = { user_id: user.id, draft_key: key, data: data, sequence: sequence, owner: owner }

      # The pre-partial-index unique index can still make a discarded row the conflict target;
      # reviving it is harmless once that index is gone.
      draft_id = DB.query_single(<<~SQL, opts).first
        INSERT INTO drafts (user_id, draft_key, data, sequence, owner, created_at, updated_at)
        VALUES (:user_id, :draft_key, :data, :sequence, :owner, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        ON CONFLICT (user_id, draft_key) WHERE deleted_at IS NULL DO
        UPDATE
        SET
          sequence = :sequence,
          data = :data,
          revisions = drafts.revisions + 1,
          owner = :owner,
          updated_at = CURRENT_TIMESTAMP,
          deleted_at = NULL
        RETURNING id
      SQL

      UserStat.update_draft_count(user.id)
    end

    UploadReference.ensure_exist!(
      upload_ids: Upload.extract_upload_ids(data),
      target_type: "Draft",
      target_id: draft_id,
    )

    sequence
  end

  def self.get(user, key, sequence)
    return if !user || !user.id || !User.human_user_id?(user.id)

    opts = { user_id: user.id, draft_key: key, sequence: sequence }

    current_sequence, data, draft_sequence = DB.query_single(<<~SQL, opts)
      WITH draft AS (
        SELECT data, sequence
        FROM drafts
        WHERE draft_key = :draft_key AND user_id = :user_id AND deleted_at IS NULL
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

    raise Draft::OutOfSequence if sequence != current_sequence

    data if current_sequence == draft_sequence
  end

  def self.clear(user, key, sequence, permanent: false)
    if !user || !user.id || !User.human_user_id?(user.id)
      raise StandardError.new("user not present")
    end

    current_sequence = DraftSequence.current(user, key)

    # bad caller is a reason to complain
    raise Draft::OutOfSequence.new("bad draft sequence") if sequence != current_sequence

    # corrupt data is not a reason not to leave data
    discard!(user.id, key, permanent: permanent)
  end

  # Discarded drafts are kept for `discarded_drafts_retention_days` so users can restore them,
  # unless the caller knows the content was posted and nothing is lost.
  def self.discard!(user_id, draft_keys, permanent: false)
    drafts = Draft.live.where(user_id: user_id, draft_key: draft_keys).to_a
    return 0 if drafts.empty?

    recoverable, disposable = permanent ? [[], drafts] : drafts.partition(&:recoverable?)

    Draft.transaction do
      Draft.where(id: recoverable.map(&:id)).update_all(deleted_at: Time.zone.now)
      UploadReference.where(target_type: "Draft", target_id: disposable.map(&:id)).delete_all
      Draft.where(id: disposable.map(&:id)).delete_all
      evict_excess_discarded!(user_id) if recoverable.any?
    end

    UserStat.update_draft_count(user_id)
    drafts.size
  end

  def self.purge_discarded!
    cutoff = SiteSetting.discarded_drafts_retention_days.days.ago

    Draft
      .discarded
      .where("deleted_at <= ?", cutoff)
      .in_batches(of: 1000) { |batch| delete_discarded!(batch.ids) }
  end

  # Discarded rows don't count towards `max_drafts_per_user`, so cap them at the same number
  # to keep a single user from growing the table without bound.
  def self.evict_excess_discarded!(user_id)
    excess_ids =
      Draft
        .discarded
        .where(user_id: user_id)
        .order(deleted_at: :desc, id: :desc)
        .offset(SiteSetting.max_drafts_per_user)
        .pluck(:id)

    delete_discarded!(excess_ids)
  end

  def self.delete_discarded!(ids)
    return if ids.empty?

    # rows go first so a draft restored meanwhile keeps its upload references
    purged_ids = DB.query_single(<<~SQL, ids: ids)
      DELETE FROM drafts WHERE id IN (:ids) AND deleted_at IS NOT NULL RETURNING id
    SQL
    UploadReference.where(target_type: "Draft", target_id: purged_ids).delete_all
  end

  private_class_method :evict_excess_discarded!, :delete_discarded!

  def restore!
    sequence = DraftSequence.current(user_id, draft_key)

    begin
      count =
        Draft
          .discarded
          .where(id: id)
          .where.not(Draft.live.where(user_id: user_id, draft_key: draft_key).arel.exists)
          .update_all(deleted_at: nil, sequence: sequence, updated_at: Time.zone.now)
    rescue ActiveRecord::RecordNotUnique
      count = 0
    end

    raise RestoreConflict if count == 0

    UserStat.update_draft_count(user_id)
    reload
  end

  def recoverable?
    return false if SiteSetting.discarded_drafts_retention_days == 0

    content = parsed_data
    content.is_a?(Hash) && (content["reply"].present? || content["title"].present?)
  end

  def display_user
    post&.user || topic&.user || user
  end

  def parsed_data
    JSON.parse(data)
  rescue JSON::ParserError
    {}
  end

  def topic_id
    draft_key.gsub(EXISTING_TOPIC, "").to_i if draft_key.starts_with?(EXISTING_TOPIC)
  end

  def topic_preloaded?
    !!defined?(@topic)
  end

  def topic
    topic_preloaded? ?
      @topic :
      @topic = Draft.allowed_draft_topics_for_user(user).find_by(id: topic_id)
  end

  def preload_topic(topic)
    @topic = topic
  end

  def post_id
    parsed_data["postId"]
  end

  def post_preloaded?
    !!defined?(@post)
  end

  def post
    post_preloaded? ? @post : @post = Draft.allowed_draft_posts_for_user(user).find_by(id: post_id)
  end

  def preload_post(post)
    @post = post
  end

  def self.preload_data(drafts, user)
    topic_ids = drafts.map(&:topic_id)
    post_ids = drafts.map(&:post_id)

    topics = allowed_draft_topics_for_user(user).where(id: topic_ids)
    posts = allowed_draft_posts_for_user(user).where(id: post_ids)

    drafts.each do |draft|
      draft.preload_topic(topics.detect { |t| t.id == draft.topic_id })
      draft.preload_post(posts.detect { |p| p.id == draft.post_id })
    end
  end

  def self.allowed_draft_topics_for_user(user)
    topics = Topic.listable_topics.secured(Guardian.new(user))
    pms = Topic.private_messages_for_user(user)
    topics.or(pms)
  end

  def self.allowed_draft_posts_for_user(user)
    # .secured handles whispers, merge handles topic/pm visibility
    Post.secured(Guardian.new(user)).joins(:topic).merge(allowed_draft_topics_for_user(user))
  end

  def self.stream(opts = nil)
    opts ||= {}

    user_id = opts[:user].id
    offset = (opts[:offset] || 0).to_i
    limit = (opts[:limit] || 30).to_i

    stream =
      Draft
        .live
        .where(user_id: user_id)
        .where(<<~SQL)
          sequence >= COALESCE(
            (SELECT sequence FROM draft_sequences
             WHERE draft_sequences.user_id = drafts.user_id
             AND draft_sequences.draft_key = drafts.draft_key),
            0
          )
        SQL
        .order(updated_at: :desc, id: :desc)
        .offset(offset)
        .limit(limit)

    # Preload posts and topics to avoid N+1 queries
    Draft.preload_data(stream, opts[:user])

    stream
  end

  def self.cleanup!
    Draft.live.where(<<~SQL).in_batches(of: 100).destroy_all
      sequence < (
        SELECT MAX(s.sequence)
          FROM draft_sequences s
          WHERE s.draft_key = drafts.draft_key
          AND s.user_id = drafts.user_id
      )
    SQL

    # remove old drafts
    delete_drafts_older_than_n_days = SiteSetting.delete_drafts_older_than_n_days.days.ago
    Draft
      .live
      .where("updated_at < ?", delete_drafts_older_than_n_days)
      .in_batches(of: 100)
      .destroy_all

    UserStat.update_draft_count
  end

  def self.backup_draft(user, key, sequence, data)
    reply = JSON.parse(data)["reply"] || ""
    return if reply.length < SiteSetting.backup_drafts_to_pm_length

    post_id = BackupDraftPost.where(user_id: user.id, key: key).pick(:post_id)
    post = Post.where(id: post_id).first if post_id

    BackupDraftPost.where(user_id: user.id, key: key).delete_all if post_id && !post

    indented_reply = reply.split("\n").map! { |l| "    #{l}" }
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
        post =
          PostCreator.new(
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
        updated_at: Time.zone.now,
      )
    else
      revisor = PostRevisor.new(post, post.topic)
      revisor.revise!(
        user,
        { raw: draft_body },
        bypass_bump: true,
        skip_validations: true,
        skip_staff_log: true,
        bypass_rate_limiter: true,
      )
    end
  rescue => e
    Discourse.warn_exception(e, message: "Failed to backup draft")
  end

  def self.ensure_draft_topic!(user)
    topic_id = BackupDraftTopic.where(user_id: user.id).pick(:topic_id)
    topic = Topic.find_by(id: topic_id) if topic_id

    BackupDraftTopic.where(user_id: user.id).delete_all if topic_id && !topic

    if !topic
      Topic.transaction do
        creator =
          PostCreator.new(
            user,
            title: I18n.t("draft_backup.pm_title"),
            archetype: Archetype.private_message,
            raw: I18n.t("draft_backup.pm_body"),
            skip_jobs: true,
            skip_validations: true,
            target_usernames: user.username,
          )
        topic = creator.create.topic
        BackupDraftTopic.create!(topic_id: topic.id, user_id: user.id)
      end
    end

    topic
  end

  def update_draft_count
    UserStat.update_draft_count(user_id)
  end
end

# == Schema Information
#
# Table name: drafts
#
#  id         :integer          not null, primary key
#  data       :text             not null
#  deleted_at :datetime
#  draft_key  :string           not null
#  owner      :string
#  revisions  :integer          default(1), not null
#  sequence   :bigint           default(0), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :integer          not null
#
# Indexes
#
#  idx_drafts_on_deleted_at                  (deleted_at) WHERE (deleted_at IS NOT NULL)
#  idx_drafts_on_user_id                     (user_id)
#  idx_drafts_on_user_id_and_draft_key_live  (user_id,draft_key) UNIQUE WHERE (deleted_at IS NULL)
#
