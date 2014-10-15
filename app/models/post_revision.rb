require_dependency "discourse_diff"

class PostRevision < ActiveRecord::Base
  belongs_to :post
  belongs_to :user

  serialize :modifications, Hash

  def self.ensure_consistency!
    # 1 - fix the numbers
    sql = <<-SQL
      UPDATE post_revisions
         SET number = pr.rank
        FROM (SELECT id, ROW_NUMBER() OVER (PARTITION BY post_id ORDER BY number, created_at, updated_at) AS rank FROM post_revisions) AS pr
       WHERE post_revisions.id = pr.id
         AND post_revisions.number <> pr.rank
    SQL

    PostRevision.exec_sql(sql)

    # 2 - fix the versions on the posts
    sql = <<-SQL
      UPDATE posts
         SET version = pv.version
        FROM (SELECT post_id, MAX(number) AS version FROM post_revisions GROUP BY post_id) AS pv
       WHERE posts.id = pv.post_id
         AND posts.version <> pv.version
    SQL

    PostRevision.exec_sql(sql)
  end

  def body_changes
    cooked_diff = DiscourseDiff.new(previous("cooked"), current("cooked"))
    raw_diff = DiscourseDiff.new(previous("raw"), current("raw"))

    {
      inline: cooked_diff.inline_html,
      side_by_side: cooked_diff.side_by_side_html,
      side_by_side_markdown: raw_diff.side_by_side_markdown
    }
  end

  def category_changes
    prev = previous("category_id")
    cur = current("category_id")
    return if prev == cur

    {
      previous_category_id: prev,
      current_category_id: cur,
    }
  end

  def wiki_changes
    prev = previous("wiki")
    cur = current("wiki")
    return if prev == cur

    {
        previous_wiki: prev,
        current_wiki: cur,
    }
  end

  def post_type_changes
    prev = previous("post_type")
    cur = current("post_type")
    return if prev == cur

    {
        previous_post_type: prev,
        current_post_type: cur,
    }
  end

  def title_changes
    prev = "<div>#{CGI::escapeHTML(previous("title"))}</div>"
    cur = "<div>#{CGI::escapeHTML(current("title"))}</div>"
    return if prev == cur

    diff = DiscourseDiff.new(prev, cur)

    {
      inline: diff.inline_html,
      side_by_side: diff.side_by_side_html
    }
  end

  def user_changes
    prev = previous("user_id")
    cur = current("user_id")
    return if prev == cur

    {
        previous_user: User.find_by(id: prev),
        current_user: User.find_by(id: cur)
    }
  end

  def previous(field)
    val = lookup(field)
    if val.nil?
      val = lookup_in_previous_revisions(field)
    end

    if val.nil?
      val = lookup_in_post(field)
    end

    val
  end

  def current(field)
    val = lookup_in_next_revision(field)
    if val.nil?
      val = lookup_in_post(field)
    end

    if val.nil?
      val = lookup(field)
    end

    if val.nil?
      val = lookup_in_previous_revisions(field)
    end

    return val
  end

  def previous_revisions
    @previous_revs ||= PostRevision.where("post_id = ? AND number < ? AND hidden = ?", post_id, number, false)
                                   .order("number desc")
                                   .to_a
  end

  def next_revision
    @next_revision ||= PostRevision.where("post_id = ? AND number > ? AND hidden = ?", post_id, number, false)
                                   .order("number asc")
                                   .to_a.first
  end

  def has_topic_data?
    post && post.post_number == 1
  end

  def lookup_in_previous_revisions(field)
    previous_revisions.each do |v|
      val = v.lookup(field)
      return val unless val.nil?
    end

    nil
  end

  def lookup_in_next_revision(field)
    if next_revision
      return next_revision.lookup(field)
    end
  end

  def lookup_in_post(field)
    if !post
      return
    elsif ["cooked", "raw"].include?(field)
      val = post.send(field)
    elsif ["title", "category_id"].include?(field)
      val = post.topic.send(field)
    end

    val
  end

  def lookup(field)
    return nil if hidden
    mod = modifications[field]
    unless mod.nil?
      mod[0]
    end
  end

  def hide!
    self.hidden = true
    self.save!
  end

  def show!
    self.hidden = false
    self.save!
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
#
# Indexes
#
#  index_post_revisions_on_post_id             (post_id)
#  index_post_revisions_on_post_id_and_number  (post_id,number)
#
