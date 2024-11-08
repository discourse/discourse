# frozen_string_literal: true

class Tag < ActiveRecord::Base
  include Searchable
  include HasDestroyedWebHook
  include HasSanitizableFields

  self.ignored_columns = [
    "topic_count", # TODO: Remove when 20240212034010_drop_deprecated_columns has been promoted to pre-deploy
  ]

  RESERVED_TAGS = [
    "none",
    "constructor", # prevents issues with javascript's constructor of objects
  ].freeze

  validates :name, presence: true, uniqueness: { case_sensitive: false }

  validate :target_tag_validator,
           if: Proc.new { |t| t.new_record? || t.will_save_change_to_target_tag_id? }
  validate :name_validator
  validates :description, length: { maximum: 1000 }

  scope :where_name,
        ->(name) do
          name = Array(name).map(&:downcase)
          where("lower(tags.name) IN (?)", name)
        end

  # tags that have never been used and don't belong to a tag group
  scope :unused,
        -> do
          where(staff_topic_count: 0, pm_topic_count: 0, target_tag_id: nil).joins(
            "LEFT JOIN tag_group_memberships tgm ON tags.id = tgm.tag_id",
          ).where("tgm.tag_id IS NULL")
        end

  scope :used_tags_in_regular_topics,
        ->(guardian) { where("tags.#{Tag.topic_count_column(guardian)} > 0") }

  scope :base_tags, -> { where(target_tag_id: nil) }
  scope :visible, ->(guardian = nil) { merge(DiscourseTagging.visible_tags(guardian)) }

  has_many :tag_users, dependent: :destroy # notification settings

  has_many :topic_tags, dependent: :destroy
  has_many :topics, through: :topic_tags

  has_many :category_tag_stats, dependent: :destroy
  has_many :category_tags, dependent: :destroy
  has_many :categories, through: :category_tags

  has_many :tag_group_memberships, dependent: :destroy
  has_many :tag_groups, through: :tag_group_memberships

  belongs_to :target_tag, class_name: "Tag", optional: true
  has_many :synonyms, class_name: "Tag", foreign_key: "target_tag_id", dependent: :destroy
  has_many :sidebar_section_links, as: :linkable, dependent: :delete_all

  has_many :embeddable_host_tags
  has_many :embeddable_hosts, through: :embeddable_host_tags

  before_save :sanitize_description

  after_save :index_search
  after_save :update_synonym_associations

  after_commit :trigger_tag_created_event, on: :create
  after_commit :trigger_tag_updated_event, on: :update
  after_commit :trigger_tag_destroyed_event, on: :destroy

  def self.ensure_consistency!
    update_topic_counts
  end

  def self.update_topic_counts
    DB.exec <<~SQL
      UPDATE tags t
         SET staff_topic_count = x.topic_count
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
         AND x.topic_count <> t.staff_topic_count
    SQL

    DB.exec <<~SQL
      UPDATE tags t
      SET public_topic_count = x.topic_count
      FROM (
        WITH tags_with_public_topics AS (
          SELECT
            COUNT(topics.id) AS topic_count,
            tags.id AS tag_id
          FROM tags
          INNER JOIN topic_tags ON tags.id = topic_tags.tag_id
          INNER JOIN topics ON topics.id = topic_tags.topic_id AND topics.deleted_at IS NULL AND topics.archetype != 'private_message'
          INNER JOIN categories ON categories.id = topics.category_id AND NOT categories.read_restricted
          GROUP BY tags.id
        )
        SELECT
          COALESCE(tags_with_public_topics.topic_count, 0 ) AS topic_count,
          tags.id AS tag_id
        FROM tags
        LEFT JOIN tags_with_public_topics ON tags_with_public_topics.tag_id = tags.id
      ) x
      WHERE x.tag_id = t.id
      AND x.topic_count <> t.public_topic_count;
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
    self.find_by("lower(name) = ?", name.downcase)
  end

  def self.top_tags(limit_arg: nil, category: nil, guardian: Guardian.new)
    # we add 1 to max_tags_in_filter_list to efficiently know we have more tags
    # than the limit. Frontend is responsible to enforce limit.
    limit = limit_arg || (SiteSetting.max_tags_in_filter_list + 1)
    scope_category_ids = guardian.allowed_category_ids
    scope_category_ids &= ([category.id] + category.subcategories.pluck(:id)) if category

    return [] if scope_category_ids.empty?

    filter_sql =
      (
        if guardian.is_staff?
          ""
        else
          " AND tags.id IN (#{DiscourseTagging.visible_tags(guardian).select(:id).to_sql})"
        end
      )

    tag_names_with_counts = DB.query <<~SQL
      SELECT tags.name as tag_name, SUM(stats.topic_count) AS sum_topic_count
        FROM category_tag_stats stats
        JOIN tags ON stats.tag_id = tags.id AND stats.topic_count > 0
       WHERE stats.category_id in (#{scope_category_ids.join(",")})
       #{filter_sql}
    GROUP BY tags.name
    ORDER BY sum_topic_count DESC, tag_name ASC
       LIMIT #{limit}
    SQL

    tag_names_with_counts.map { |row| row.tag_name }
  end

  def self.topic_count_column(guardian)
    if guardian&.is_staff? || SiteSetting.include_secure_categories_in_tag_counts
      "staff_topic_count"
    else
      "public_topic_count"
    end
  end

  def self.pm_tags(limit: 1000, guardian: nil, allowed_user: nil)
    return [] if allowed_user.blank? || !(guardian || Guardian.new).can_tag_pms?
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
           WHERE user_id = #{user_id.to_i}
           UNION
          SELECT tg.topic_id
            FROM topic_allowed_groups tg
            JOIN group_users gu ON gu.user_id = #{user_id.to_i}
                               AND gu.group_id = tg.group_id
       )
       GROUP BY tags.name
       ORDER BY count DESC
       LIMIT #{limit.to_i}
    SQL
  end

  def self.include_tags?
    SiteSetting.tagging_enabled
  end

  def url
    "#{Discourse.base_path}/tag/#{UrlHelper.encode_component(self.name)}"
  end

  alias_method :relative_url, :url

  def full_url
    "#{Discourse.base_url}/tag/#{UrlHelper.encode_component(self.name)}"
  end

  def index_search
    SearchIndexer.index(self)
  end

  def synonym?
    !self.target_tag_id.nil?
  end

  def target_tag_validator
    if synonyms.exists?
      errors.add(:target_tag_id, I18n.t("tags.synonyms_exist"))
    elsif target_tag&.synonym?
      errors.add(:target_tag_id, I18n.t("tags.invalid_target_tag"))
    end
  end

  def update_synonym_associations
    if target_tag_id && saved_change_to_target_tag_id?
      target_tag.tag_groups.each do |tag_group|
        tag_group.tags << self if tag_group.tags.exclude?(self)
      end
      target_tag.categories.each do |category|
        category.tags << self if category.tags.exclude?(self)
      end
    end
  end

  def all_category_ids
    @all_category_ids ||=
      categories.pluck(:id) +
        tag_groups.includes(:categories).flat_map { |tg| tg.categories.map(&:id) }
  end

  def all_categories(guardian)
    categories = Category.secured(guardian).where(id: all_category_ids)
    Category.preload_user_fields!(guardian, categories)
    categories
  end

  %i[tag_created tag_updated tag_destroyed].each do |event|
    define_method("trigger_#{event}_event") do
      DiscourseEvent.trigger(event, self)
      true
    end
  end

  private

  def sanitize_description
    self.description = sanitize_field(self.description) if description_changed?
  end

  def name_validator
    errors.add(:name, :invalid) if name.present? && RESERVED_TAGS.include?(self.name.strip.downcase)
  end
end

# == Schema Information
#
# Table name: tags
#
#  id                 :integer          not null, primary key
#  name               :string           not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  pm_topic_count     :integer          default(0), not null
#  target_tag_id      :integer
#  description        :string(1000)
#  public_topic_count :integer          default(0), not null
#  staff_topic_count  :integer          default(0), not null
#
# Indexes
#
#  index_tags_on_lower_name  (lower((name)::text)) UNIQUE
#  index_tags_on_name        (name) UNIQUE
#
