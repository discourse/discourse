# frozen_string_literal: true

class Draft < ActiveRecord::Base
  NEW_TOPIC = "new_topic"
  NEW_PRIVATE_MESSAGE = "new_private_message"
  EXISTING_TOPIC = "topic_"

  belongs_to :user

  has_many :upload_references, as: :target, dependent: :delete_all

  validates :draft_key, length: { maximum: 40 }

  after_commit :update_draft_count, on: %i[create destroy]

  class OutOfSequence < StandardError
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

      draft_id = DB.query_single(<<~SQL, opts).first
        INSERT INTO drafts (user_id, draft_key, data, sequence, owner, created_at, updated_at)
        VALUES (:user_id, :draft_key, :data, :sequence, :owner, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        ON CONFLICT (user_id, draft_key) DO
        UPDATE
        SET
          sequence = :sequence,
          data = :data,
          revisions = drafts.revisions + 1,
          owner = :owner,
          updated_at = CURRENT_TIMESTAMP
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

    raise Draft::OutOfSequence if sequence != current_sequence

    data if current_sequence == draft_sequence
  end

  def self.clear(user, key, sequence)
    if !user || !user.id || !User.human_user_id?(user.id)
      raise StandardError.new("user not present")
    end

    current_sequence = DraftSequence.current(user, key)

    # bad caller is a reason to complain
    raise Draft::OutOfSequence.new("bad draft sequence") if sequence != current_sequence

    # corrupt data is not a reason not to leave data
    Draft.where(user_id: user.id, draft_key: key).destroy_all
  end

  def display_user
    post&.user || topic&.user || user
  end

  def parsed_data
    begin
      JSON.parse(data)
    rescue JSON::ParserError
      {}
    end
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

    topics = self.allowed_draft_topics_for_user(user).where(id: topic_ids)
    posts = self.allowed_draft_posts_for_user(user).where(id: post_ids)

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
    Post.secured(Guardian.new(user)).joins(:topic).merge(self.allowed_draft_topics_for_user(user))
  end

  def self.stream(opts = nil)
    opts ||= {}

    user_id = opts[:user].id
    offset = (opts[:offset] || 0).to_i
    limit = (opts[:limit] || 30).to_i

    stream = Draft.where(user_id: user_id).order(updated_at: :desc).offset(offset).limit(limit)

    # Preload posts and topics to avoid N+1 queries
    Draft.preload_data(stream, opts[:user])

    stream
  end

  def self.cleanup!
    Draft.where(<<~SQL).in_batches(of: 100).destroy_all
      sequence < (
        SELECT MAX(s.sequence)
          FROM draft_sequences s
          WHERE s.draft_key = drafts.draft_key
          AND s.user_id = drafts.user_id
      )
    SQL

    # remove old drafts
    delete_drafts_older_than_n_days = SiteSetting.delete_drafts_older_than_n_days.days.ago
    Draft.where("updated_at < ?", delete_drafts_older_than_n_days).in_batches(of: 100).destroy_all

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
    UserStat.update_draft_count(self.user_id)
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
#  sequence   :bigint           default(0), not null
#  revisions  :integer          default(1), not null
#  owner      :string
#
# Indexes
#
#  index_drafts_on_user_id_and_draft_key  (user_id,draft_key) UNIQUE
#
