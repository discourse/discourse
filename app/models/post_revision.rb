# frozen_string_literal: true

class PostRevision < ActiveRecord::Base
  belongs_to :post
  belongs_to :user

  # The history modal only loads this many of a post's newest revisions.
  HISTORY_WINDOW = 99

  attr_accessor :silent

  serialize :modifications, type: Hash, coder: YAML

  after_create :create_notification

  def self.ensure_consistency!
    # 1 - fix the numbers
    DB.exec <<-SQL
      UPDATE post_revisions
         SET number = pr.rank
        FROM (SELECT id, 1 + ROW_NUMBER() OVER (PARTITION BY post_id ORDER BY number, created_at, updated_at) AS rank FROM post_revisions) AS pr
       WHERE post_revisions.id = pr.id
         AND post_revisions.number <> pr.rank
    SQL

    # 2 - fix the versions on the posts
    DB.exec <<-SQL
      UPDATE posts
         SET version = 1 + (SELECT COUNT(*) FROM post_revisions WHERE post_id = posts.id),
             public_version = 1 + (SELECT COUNT(*) FROM post_revisions pr WHERE post_id = posts.id AND pr.hidden = 'f')
       WHERE version <> 1 + (SELECT COUNT(*) FROM post_revisions WHERE post_id = posts.id)
          OR public_version <> 1 + (SELECT COUNT(*) FROM post_revisions pr WHERE post_id = posts.id AND pr.hidden = 'f')
    SQL
  end

  # Unlisted revisions are public, so one is still opened when no listed one is left among the
  # revisions the history loads.
  def self.latest_for(post, guardian, include_unlisted: false)
    revisions = where(post_id: post.id).order(:number)
    revisions = revisions.where(hidden: false) if !guardian.can_view_hidden_post_revisions?
    return revisions.last if include_unlisted || guardian.can_navigate_unlisted_post_revisions?

    loaded_numbers =
      where(post_id: post.id).order(number: :desc).limit(HISTORY_WINDOW).select(:number)
    revisions.where(unlisted: false, number: loaded_numbers).last || revisions.last
  end

  def categories
    return [] if modifications["category_id"].blank?

    @categories ||= Category.with_parents(modifications["category_id"])
  end

  def hide!
    update_columns(hidden: true, unlisted: false)
  end

  def show!
    update_column(:hidden, false)
  end

  # Unlisting only trims what non-staff step through in the history; `hidden` is what
  # restricts access.
  def unlist!
    update_column(:unlisted, true)
  end

  def relist!
    update_column(:unlisted, false)
  end

  def create_notification
    PostActionNotifier.after_create_post_revision(self)
  end

  def self.copy(original_post, target_post)
    cols_to_copy = (column_names - %w[id post_id]).join(", ")

    DB.exec <<~SQL
    INSERT INTO post_revisions(post_id, #{cols_to_copy})
    SELECT #{target_post.id}, #{cols_to_copy}
    FROM post_revisions
    WHERE post_id = #{original_post.id}
    SQL
  end
end

# == Schema Information
#
# Table name: post_revisions
#
#  id            :integer          not null, primary key
#  hidden        :boolean          default(FALSE), not null
#  modifications :text
#  number        :integer
#  unlisted      :boolean          default(FALSE), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  post_id       :integer
#  user_id       :integer
#
# Indexes
#
#  index_post_revisions_on_post_id             (post_id)
#  index_post_revisions_on_post_id_and_number  (post_id,number)
#  index_post_revisions_on_user_id             (user_id)
#
