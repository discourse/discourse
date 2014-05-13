require_dependency "discourse_diff"

class PostRevision < ActiveRecord::Base
  belongs_to :post
  belongs_to :user

  serialize :modifications, Hash

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
    prev = lookup("wiki", 0)
    cur = lookup("wiki", 1)
    return if prev == cur

    {
        previous_wiki: prev,
        current_wiki: cur,
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
    lookup_with_fallback(field, 0)
  end

  def current(field)
    lookup_with_fallback(field, 1)
  end

  def previous_revisions
    @previous_revs ||= PostRevision.where("post_id = ? AND number < ?", post_id, number)
                                   .order("number desc")
                                   .to_a
  end

  def has_topic_data?
    post && post.post_number == 1
  end

  def lookup_with_fallback(field, index)

    unless val = lookup(field, index)
      previous_revisions.each do |v|
        break if val = v.lookup(field, 1)
      end
    end

    unless val
      if ["cooked", "raw"].include?(field)
        val = post.send(field)
      else
        val = post.topic.send(field)
      end
    end

    val
  end

  def lookup(field, index)
    if mod = modifications[field]
      mod[index]
    end
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
#  created_at    :datetime
#  updated_at    :datetime
#
# Indexes
#
#  index_post_revisions_on_post_id             (post_id)
#  index_post_revisions_on_post_id_and_number  (post_id,number)
#
