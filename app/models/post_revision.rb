require_dependency "discourse_diff"

class PostRevision < ActiveRecord::Base
  belongs_to :post
  belongs_to :user

  serialize :modifications, Hash

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

  def hide!
    update_column(:hidden, true)
  end

  def show!
    update_column(:hidden, false)
  end

  def create_notification
    PostActionNotifier.after_create_post_revision(self)
  end

end

# == Schema Information
#
# Table name: post_revisions
#
#  id            :integer          not null, primary key
#  user_id       :integer
#  post_id       :integer
#  modifications :text
#  number        :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  hidden        :boolean          default(FALSE), not null
#
# Indexes
#
#  index_post_revisions_on_post_id             (post_id)
#  index_post_revisions_on_post_id_and_number  (post_id,number)
#
