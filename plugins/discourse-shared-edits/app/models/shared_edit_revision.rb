# frozen_string_literal: true

class SharedEditRevision < ActiveRecord::Base
  belongs_to :post
  belongs_to :post_revision

  def self.will_commit_key(post_id)
    "shared_revision_will_commit_#{post_id}"
  end

  def self.ensure_will_commit(post_id)
    key = will_commit_key(post_id)
    if !Discourse.redis.get(key)
      # Set lock for 5 seconds and schedule commit in 5 seconds
      Discourse.redis.setex(key, 5, "1")
      Jobs.enqueue_in(5.seconds, :commit_shared_revision, post_id: post_id)
      Rails.logger.info "[SharedEdits] Scheduled auto-commit for post #{post_id} in 5 seconds"
    end
  end

  def self.last_revision_id_for_post(post)
    PostRevision.where(post: post).limit(1).order("number desc").pluck(:id).first || -1
  end

  def self.toggle_shared_edits!(post_id, enable)
    post = Post.find(post_id)
    if enable
      init!(post)
      post.custom_fields[DiscourseSharedEdits::SHARED_EDITS_ENABLED] = true
    else
      commit!(post_id)
      SharedEditRevision.where(post_id: post_id).delete_all
      post.custom_fields.delete(DiscourseSharedEdits::SHARED_EDITS_ENABLED)
    end
    post.save_custom_fields
  end

  def self.init!(post)
    if !SharedEditRevision.where(post_id: post.id).exists?
      revision_id = last_revision_id_for_post(post)

      # Create initial Yjs state
      initial_yjs_state = YjsTextOperations.create_initial_state(post.raw)

      SharedEditRevision.create!(
        post: post,
        client_id: "system",
        user_id: Discourse.system_user.id,
        version: 1,
        revision: initial_yjs_state,
        raw: post.raw,
        post_revision_id: revision_id,
      )
    end
  end

  def self.commit!(post_id, apply_to_post: true)
    Rails.logger.info "[SharedEdits] Starting commit for post #{post_id}, apply_to_post: #{apply_to_post}"

    version_with_raw =
      SharedEditRevision
        .where(post_id: post_id)
        .where("raw IS NOT NULL")
        .order("version desc")
        .first

    if !version_with_raw
      Rails.logger.warn "[SharedEdits] No revisions with raw content found for post #{post_id}"
      return
    end

    Rails.logger.info "[SharedEdits] Found version with raw: #{version_with_raw.version}, raw_length: #{version_with_raw.raw&.length}"

    raw = version_with_raw.raw

    to_resolve =
      SharedEditRevision
        .where(post_id: post_id)
        .where("version > ?", version_with_raw.version)
        .order(:version)

    Rails.logger.info "[SharedEdits] Revisions to resolve: #{to_resolve.count}"

    last_revision = version_with_raw

    editors = []

    to_resolve.each do |rev|
      # For Yjs, we extract the content from the stored state
      extracted_raw = YjsTextOperations.get_text_content(rev.revision)
      Rails.logger.info "[SharedEdits] Version #{rev.version}: extracted_raw_length: #{extracted_raw&.length}"

      # Only update if we got actual content
      raw = extracted_raw if extracted_raw.present?

      last_revision = rev
      editors << rev.user_id
    end

    Rails.logger.info "[SharedEdits] Final raw content length: #{raw&.length}, preview: #{raw&.[](0..100)}"

    last_revision.update!(raw: raw) if last_revision.raw != raw

    if last_revision.post_revision_id
      Rails.logger.info "[SharedEdits] Revision already has post_revision_id, skipping"
      return
    end

    if !apply_to_post
      Rails.logger.info "[SharedEdits] apply_to_post is false, skipping post update"
      return
    end

    post = Post.find(post_id)

    Rails.logger.info "[SharedEdits] Current post.raw length: #{post.raw&.length}"
    Rails.logger.info "[SharedEdits] New raw length: #{raw&.length}"
    Rails.logger.info "[SharedEdits] Content changed: #{post.raw != raw}"

    if post.raw == raw
      Rails.logger.info "[SharedEdits] Content unchanged, skipping post update"
      return raw
    end

    revisor = PostRevisor.new(post)

    # TODO decide if we need fidelity here around skip_revision
    # skip_revision: true

    opts = { bypass_rate_limiter: true, bypass_bump: true, skip_staff_log: true }

    Rails.logger.info "[SharedEdits] Calling revisor.revise! with raw content"

    # revise must be called outside of transaction
    # otherwise you get phantom edits where and edit can take 2 cycles
    # to take
    done = revisor.revise!(Discourse.system_user, { raw: raw }, opts)

    Rails.logger.info "[SharedEdits] revisor.revise! result: #{done}"

    Post.transaction do
      if done
        last_post_revision = PostRevision.where(post: post).limit(1).order("number desc").first

        reason = last_post_revision.modifications["edit_reason"] || ""

        reason = reason[1] if Array === reason

        usernames = reason&.split(",")&.map(&:strip) || []

        if usernames.length > 0
          reason_length = I18n.t("shared_edits.reason", users: "").length
          usernames[0] = usernames[0][reason_length..-1]
        end

        User.where(id: editors).pluck(:username).each { |name| usernames << name }

        usernames.uniq!

        new_reason = I18n.t("shared_edits.reason", users: usernames.join(", "))

        if new_reason != reason
          last_post_revision.modifications["edit_reason"] = [nil, new_reason]
          last_post_revision.save!
          post.update!(edit_reason: new_reason)
        end

        last_revision.update!(post_revision_id: last_post_revision.id)
      end
    end

    raw
  end

  def self.latest_raw(post_id)
    SharedEditRevision
      .where("raw IS NOT NULL")
      .where(post_id: post_id)
      .order("version desc")
      .limit(1)
      .pluck(:version, :raw, :revision)
      .first
  end

  def self.revise!(post_id:, user_id:, client_id:, revision:, version:, raw: nil)
    revision = revision.to_json if !(String === revision)

    # Add validation to prevent empty or invalid updates
    if revision.blank? || (revision.is_a?(String) && revision.length < 2)
      Rails.logger.warn "[SharedEdits] Rejecting empty or invalid revision for post #{post_id}"
      current_version = SharedEditRevision.where(post_id: post_id).maximum(:version) || 0
      return current_version, revision
    end

    args = {
      user_id: user_id,
      client_id: client_id,
      revision: revision,
      raw: raw,
      post_id: post_id,
      version: version + 1,
      now: Time.zone.now,
    }

    # Use a transaction to ensure atomicity
    rows = DB.exec(<<~SQL, args)
      INSERT INTO shared_edit_revisions
      (
        post_id,
        user_id,
        client_id,
        revision,
        raw,
        version,
        created_at,
        updated_at
      )
      SELECT
        :post_id,
        :user_id,
        :client_id,
        :revision,
        :raw,
        :version,
        :now,
        :now
      WHERE :version = (
        SELECT COALESCE(MAX(version), 0) + 1
        FROM shared_edit_revisions
        WHERE post_id = :post_id
      )
    SQL

    if rows == 1
      # Successfully inserted at the expected version
      Rails.logger.info "[SharedEdits] Successfully inserted revision v#{version + 1} for post #{post_id}"

      post = Post.find(post_id)
      message = { version: version + 1, revision: revision, client_id: client_id, user_id: user_id }

      # Wrap message bus publish in rescue to prevent failures from blocking the edit
      begin
        post.publish_message!("/shared_edits/#{post.id}", message)
      rescue => e
        Rails.logger.error "[SharedEdits] Failed to publish message bus update: #{e.message}"
        # Continue anyway - the revision is saved
      end

      [version + 1, revision]
    else
      # Version conflict - retrieve missing revisions and merge
      Rails.logger.info "[SharedEdits] Version conflict detected for post #{post_id}, version #{version}"

      missing =
        SharedEditRevision
          .where(post_id: post_id)
          .where("version > ?", version)
          .order(:version)
          .pluck(:version, :revision)

      if missing.length == 0
        Rails.logger.error "[SharedEdits] No revisions to apply for post #{post_id}, version #{version}"
        raise StandardError, "no revisions to apply"
      end

      Rails.logger.info "[SharedEdits] Found #{missing.length} missing revisions to merge"

      missing.each do |missing_version, missing_revision|
        # For Yjs, we need to merge the updates instead of transforming
        revision = YjsTextOperations.merge_updates([revision, missing_revision])
        version = missing_version
      end

      revise!(
        post_id: post_id,
        user_id: user_id,
        client_id: client_id,
        revision: revision,
        version: version,
      )
    end
  end
end

# == Schema Information
#
# Table name: shared_edit_revisions
#
#  id               :bigint           not null, primary key
#  post_id          :integer          not null
#  raw              :string
#  revision         :string           not null
#  user_id          :integer          not null
#  client_id        :string           not null
#  version          :integer          not null
#  post_revision_id :integer
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_shared_edit_revisions_on_post_id_and_version  (post_id,version) UNIQUE
#
