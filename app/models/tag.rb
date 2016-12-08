class Tag < ActiveRecord::Base
  validates :name, presence: true, uniqueness: true

  has_many :tag_users # notification settings

  has_many :topic_tags, dependent: :destroy
  has_many :topics, through: :topic_tags

  has_many :category_tags, dependent: :destroy
  has_many :categories, through: :category_tags

  has_many :tag_group_memberships
  has_many :tag_groups, through: :tag_group_memberships

  COUNT_ARG = "topic_tags.id"

  # Apply more activerecord filters to the tags_by_count_query, and then
  # fetch the result with .count(Tag::COUNT_ARG).
  #
  # e.g., Tag.tags_by_count_query.where("topics.category_id = ?", category.id).count(Tag::COUNT_ARG)
  def self.tags_by_count_query(opts={})
    q = Tag.joins("LEFT JOIN topic_tags ON tags.id = topic_tags.tag_id")
           .joins("LEFT JOIN topics ON topics.id = topic_tags.topic_id")
           .group("tags.id, tags.name")
           .order('count_topic_tags_id DESC')
    q = q.limit(opts[:limit]) if opts[:limit]
    q
  end

  def self.category_tags_by_count_query(category, opts={})
    tags_by_count_query(opts).where("tags.id in (select tag_id from category_tags where category_id = ?)", category.id)
                             .where("topics.category_id = ?", category.id)
  end

  def self.top_tags(limit_arg: nil, category: nil, guardian: nil)
    limit = limit_arg || SiteSetting.max_tags_in_filter_list
    scope_category_ids = (guardian||Guardian.new).allowed_category_ids

    if category
      scope_category_ids &= ([category.id] + category.subcategories.pluck(:id))
    end

    tags = DiscourseTagging.filter_allowed_tags(
      tags_by_count_query(limit: limit).where("topics.category_id in (?)", scope_category_ids),
      nil, # Don't pass guardian. You might not be able to use some tags, but should still be able to see where they've been used.
      category: category
    )

    tags.count(COUNT_ARG).map {|name, _| name}
  end

  def self.include_tags?
    SiteSetting.tagging_enabled && SiteSetting.show_filter_by_tag
  end

  def full_url
    "#{Discourse.base_url}/tags/#{self.name}"
  end
end

# == Schema Information
#
# Table name: tags
#
#  id          :integer          not null, primary key
#  name        :string           not null
#  topic_count :integer          default(0), not null
#  created_at  :datetime
#  updated_at  :datetime
#
# Indexes
#
#  index_tags_on_name  (name) UNIQUE
#
