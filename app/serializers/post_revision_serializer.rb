require_dependency "discourse_diff"

class PostRevisionSerializer < ApplicationSerializer
  attributes :post_id,
             :version,
             :revisions_count,
             :username,
             :display_username,
             :avatar_template,
             :created_at,
             :edit_reason,
             :inline,
             :side_by_side,
             :side_by_side_markdown

  def version
    object.number
  end

  def revisions_count
    object.post.version
  end

  def username
    object.user.username_lower
  end

  def display_username
    object.user.username
  end

  def avatar_template
    object.user.avatar_template
  end

  def edit_reason
    return unless object.modifications["edit_reason"].present?
    object.modifications["edit_reason"][1]
  end

  def inline
    DiscourseDiff.new(previous_cooked, cooked).inline_html
  end

  def side_by_side
    DiscourseDiff.new(previous_cooked, cooked).side_by_side_html
  end

  def side_by_side_markdown
    DiscourseDiff.new(previous_raw, raw).side_by_side_markdown
  end

  private

  def previous_cooked
    @previous_cooked ||= object.modifications["cooked"][0]
  end

  def previous_raw
    @previous_raw ||= object.modifications["raw"][0]
  end

  def cooked
    @cooked ||= object.modifications["cooked"][1]
  end

  def raw
    @raw ||= object.modifications["raw"][1]
  end

end
