class Tag < ActiveRecord::Base
  include Searchable

  validates :name, presence: true, uniqueness: true

  has_many :tag_users # notification settings

  has_many :topic_tags, dependent: :destroy
  has_many :topics, through: :topic_tags

  has_many :category_tags, dependent: :destroy
  has_many :categories, through: :category_tags

  has_many :tag_group_memberships
  has_many :tag_groups, through: :tag_group_memberships

  after_save :index_search

  def self.ensure_consistency!
    update_topic_counts # topic_count counter cache can miscount
  end

  def self.update_topic_counts
    Category.exec_sql <<~SQL
      UPDATE tags t
      SET topic_count = x.topic_count
      FROM (
        SELECT COUNT(topics.id) AS topic_count, tags.id AS tag_id
        FROM tags
        LEFT JOIN topic_tags ON tags.id = topic_tags.tag_id
        LEFT JOIN topics ON topics.id = topic_tags.topic_id AND topics.deleted_at IS NULL AND topics.archetype != 'private_message'
        GROUP BY tags.id
      ) x
      WHERE x.tag_id = t.id
        AND x.topic_count <> t.topic_count
    SQL
  end

  def self.top_tags(limit_arg: nil, category: nil, guardian: nil)
    limit = limit_arg || SiteSetting.max_tags_in_filter_list
    scope_category_ids = (guardian || Guardian.new).allowed_category_ids

    if category
      scope_category_ids &= ([category.id] + category.subcategories.pluck(:id))
    end

    return [] if scope_category_ids.empty?

    tag_names_with_counts = Tag.exec_sql <<~SQL
      SELECT tags.name as tag_name, SUM(stats.topic_count) AS sum_topic_count
        FROM category_tag_stats stats
  INNER JOIN tags ON stats.tag_id = tags.id AND stats.topic_count > 0
       WHERE stats.category_id in (#{scope_category_ids.join(',')})
    GROUP BY tags.name
    ORDER BY sum_topic_count DESC, tag_name ASC
       LIMIT #{limit}
    SQL

    tag_names_with_counts.map { |row| row['tag_name'] }
  end

  def self.include_tags?
    SiteSetting.tagging_enabled && SiteSetting.show_filter_by_tag
  end

  def full_url
    "#{Discourse.base_url}/tags/#{self.name}"
  end

  def index_search
    SearchIndexer.index(self)
  end
end

# == Schema Information
#
# Table name: tags
#
#  id          :integer          not null, primary key
#  name        :string           not null
#  topic_count :integer          default(0), not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_tags_on_name  (name) UNIQUE
#
