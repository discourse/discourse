class Tag < ActiveRecord::Base
  include Searchable
  include HasDestroyedWebHook

  validates :name, presence: true, uniqueness: { case_sensitive: false }

  scope :where_name, ->(name) do
    name = Array(name).map(&:downcase)
    where("lower(name) IN (?)", name)
  end

  scope :unused, -> { where(topic_count: 0, pm_topic_count: 0) }

  has_many :tag_users # notification settings

  has_many :topic_tags, dependent: :destroy
  has_many :topics, through: :topic_tags

  has_many :category_tags, dependent: :destroy
  has_many :categories, through: :category_tags

  has_many :tag_group_memberships
  has_many :tag_groups, through: :tag_group_memberships

  after_save :index_search

  after_commit :trigger_tag_created_event, on: :create
  after_commit :trigger_tag_updated_event, on: :update
  after_commit :trigger_tag_destroyed_event, on: :destroy

  def self.ensure_consistency!
    update_topic_counts
  end

  def self.update_topic_counts
    DB.exec <<~SQL
      UPDATE tags t
         SET topic_count = x.topic_count
        FROM (
             SELECT COUNT(topics.id) AS topic_count, tags.id AS tag_id
               FROM tags
          LEFT JOIN topic_tags ON tags.id = topic_tags.tag_id
          LEFT JOIN topics ON topics.id = topic_tags.topic_id
                          AND topics.deleted_at IS NULL
                          AND topics.archetype != 'private_message'
           GROUP BY tags.id
        ) x
       WHERE x.tag_id = t.id
         AND x.topic_count <> t.topic_count
    SQL

    DB.exec <<~SQL
      UPDATE tags t
         SET pm_topic_count = x.pm_topic_count
        FROM (
             SELECT COUNT(topics.id) AS pm_topic_count, tags.id AS tag_id
               FROM tags
          LEFT JOIN topic_tags ON tags.id = topic_tags.tag_id
          LEFT JOIN topics ON topics.id = topic_tags.topic_id
                          AND topics.deleted_at IS NULL
                          AND topics.archetype = 'private_message'
           GROUP BY tags.id
        ) x
       WHERE x.tag_id = t.id
         AND x.pm_topic_count <> t.pm_topic_count
    SQL
  end

  def self.find_by_name(name)
    self.find_by('lower(name) = ?', name.downcase)
  end

  def self.top_tags(limit_arg: nil, category: nil, guardian: nil)
    limit = limit_arg || SiteSetting.max_tags_in_filter_list
    scope_category_ids = (guardian || Guardian.new).allowed_category_ids

    if category
      scope_category_ids &= ([category.id] + category.subcategories.pluck(:id))
    end

    return [] if scope_category_ids.empty?

    filter_sql = guardian&.is_staff? ? '' : " AND tags.id NOT IN (#{DiscourseTagging.hidden_tags_query.select(:id).to_sql})"

    tag_names_with_counts = DB.query <<~SQL
      SELECT tags.name as tag_name, SUM(stats.topic_count) AS sum_topic_count
        FROM category_tag_stats stats
        JOIN tags ON stats.tag_id = tags.id AND stats.topic_count > 0
       WHERE stats.category_id in (#{scope_category_ids.join(',')})
       #{filter_sql}
    GROUP BY tags.name
    ORDER BY sum_topic_count DESC, tag_name ASC
       LIMIT #{limit}
    SQL

    tag_names_with_counts.map { |row| row.tag_name }
  end

  def self.pm_tags(limit_arg: nil, guardian: nil, allowed_user: nil)
    return [] if allowed_user.blank? || !(guardian || Guardian.new).can_tag_pms?
    limit = limit_arg || SiteSetting.max_tags_in_filter_list
    user_id = allowed_user.id

    DB.query_hash(<<~SQL).map!(&:symbolize_keys!)
      SELECT tags.name as id, tags.name as text, COUNT(topics.id) AS count
        FROM tags
        JOIN topic_tags ON tags.id = topic_tags.tag_id
        JOIN topics ON topics.id = topic_tags.topic_id
                   AND topics.deleted_at IS NULL
                   AND topics.archetype = 'private_message'
       WHERE topic_tags.topic_id IN (
          SELECT topic_id
            FROM topic_allowed_users
           WHERE user_id = #{user_id}
           UNION
          SELECT tg.topic_id
            FROM topic_allowed_groups tg
            JOIN group_users gu ON gu.user_id = #{user_id}
                               AND gu.group_id = tg.group_id
       )
       GROUP BY tags.name
       LIMIT #{limit}
    SQL
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

  %i{
    tag_created
    tag_updated
    tag_destroyed
  }.each do |event|
    define_method("trigger_#{event}_event") do
      DiscourseEvent.trigger(event, self)
      true
    end
  end
end

# == Schema Information
#
# Table name: tags
#
#  id             :integer          not null, primary key
#  name           :string           not null
#  topic_count    :integer          default(0), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  pm_topic_count :integer          default(0), not null
#
# Indexes
#
#  index_tags_on_lower_name  (lower((name)::text)) UNIQUE
#  index_tags_on_name        (name) UNIQUE
#
