require_dependency "discourse_diff"

class PostRevision < ActiveRecord::Base
  belongs_to :post
  belongs_to :user

  serialize :modifications, Hash

  def body_changes
    changes_for("cooked", "raw")
  end

  def category_changes
    {
      previous_category_id: previous("category_id"),
      current_category_id: current("category_id"),
    }
  end

  def title_changes
    changes_for("title", nil, true)
  end

  def changes_for(name, markdown=nil, wrap=false)
    prev = previous(name)
    cur = current(name)

    if wrap
      prev = "<div>#{CGI::escapeHTML(prev)}</div>"
      cur = "<div>#{CGI::escapeHTML(cur)}</div>"
    end

    diff = DiscourseDiff.new(prev, cur)

    result = {
      inline: diff.inline_html,
      side_by_side: diff.side_by_side_html
    }

    if markdown
      diff = DiscourseDiff.new(previous(markdown), current(markdown))
      result[:side_by_side_markdown] = diff.side_by_side_markdown
    end

    result
  end

  def previous(field)
    lookup_with_fallback(field, 0)
  end

  def current(field)
    lookup_with_fallback(field, 1)
  end

  def previous_revisions
    @previous_revs ||=
      PostRevision.where("post_id = ? AND number < ?",
                              post_id,        number
                      )
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
      if ["cooked","raw"].include?(field)
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
