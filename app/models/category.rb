require_dependency "concern/positionable"

class Category < ActiveRecord::Base

  include Concern::Positionable

  belongs_to :topic, dependent: :destroy
  if rails4?
    belongs_to :topic_only_relative_url,
                -> { select "id, title, slug" },
                class_name: "Topic",
                foreign_key: "topic_id"
  else
    belongs_to :topic_only_relative_url,
                select: "id, title, slug",
                class_name: "Topic",
                foreign_key: "topic_id"
  end

  belongs_to :user
  belongs_to :latest_post, class_name: "Post"

  has_many :topics
  has_many :category_featured_topics
  has_many :featured_topics, through: :category_featured_topics, source: :topic

  has_many :category_featured_users
  has_many :featured_users, through: :category_featured_users, source: :user

  has_many :category_groups
  has_many :groups, through: :category_groups

  validates :user_id, presence: true
  validates :name, presence: true, uniqueness: true, length: { in: 1..50 }
  validate :parent_category_validator

  before_validation :ensure_slug
  after_save :invalidate_site_cache
  before_save :apply_permissions
  after_create :create_category_definition
  after_create :publish_categories_list
  after_destroy :invalidate_site_cache
  after_destroy :publish_categories_list

  has_one :category_search_data
  belongs_to :parent_category, class_name: 'Category'

  scope :latest, ->{ order('topic_count desc') }

  scope :secured, ->(guardian = nil) {
    ids = guardian.secure_category_ids if guardian
    if ids.present?
      where("NOT categories.read_restricted or categories.id in (:cats)", cats: ids).references(:categories)
    else
      where("NOT categories.read_restricted").references(:categories)
    end
  }

  scope :topic_create_allowed, ->(guardian) {
    if guardian.anonymous?
      where("1=0")
    else
      scoped_to_permissions(guardian, [:full])
    end
  }

  scope :post_create_allowed, ->(guardian) {
    if guardian.anonymous?
      where("1=0")
    else
      scoped_to_permissions(guardian, [:create_post, :full])
    end
  }
  delegate :post_template, to: 'self.class'

  # permission is just used by serialization
  # we may consider wrapping this in another spot
  attr_accessor :displayable_topics, :permission, :subcategory_ids


  def self.scoped_to_permissions(guardian, permission_types)
    if guardian && guardian.is_staff?
      rails4? ? all : scoped
    else
      permission_types = permission_types.map{ |permission_type|
        CategoryGroup.permission_types[permission_type]
      }
      where("categories.id in (
            SELECT c.id FROM categories c
              WHERE (
                  NOT c.read_restricted AND
                  (
                    NOT EXISTS(
                      SELECT 1 FROM category_groups cg WHERE cg.category_id = categories.id )
                    ) OR EXISTS(
                      SELECT 1 FROM category_groups cg
                        WHERE permission_type in (?) AND
                        cg.category_id = categories.id AND
                        group_id IN (
                          SELECT g.group_id FROM group_users g where g.user_id = ? UNION SELECT ?
                        )
                    )
                  )
            )", permission_types,(!guardian || guardian.user.blank?) ? -1 : guardian.user.id, Group[:everyone].id)
    end
  end

  # Internal: Update category stats: # of topics in past year, month, week for
  # all categories.
  def self.update_stats
    topics = Topic
               .select("COUNT(*) topic_count")
               .where("topics.category_id = categories.id")
               .where("categories.topic_id <> topics.id")
               .visible

    topics_with_post_count = Topic
                              .select("topics.category_id, COUNT(*) topic_count, SUM(topics.posts_count) post_count")
                              .where("topics.id NOT IN (select cc.topic_id from categories cc WHERE topic_id IS NOT NULL)")
                              .group("topics.category_id")
                              .visible.to_sql

    topics_year = topics.created_since(1.year.ago).to_sql
    topics_month = topics.created_since(1.month.ago).to_sql
    topics_week = topics.created_since(1.week.ago).to_sql


    Category.exec_sql <<SQL
    UPDATE categories c
    SET   topic_count = x.topic_count,
          post_count = x.post_count
    FROM (#{topics_with_post_count}) x
    WHERE x.category_id = c.id AND
          (c.topic_count <> x.topic_count OR c.post_count <> x.post_count)

SQL


    # TODO don't update unchanged data
    Category.update_all("topics_year = (#{topics_year}),
                         topics_month = (#{topics_month}),
                         topics_week = (#{topics_week})")
  end

  # Internal: Generate the text of post prompting to enter category
  # description.
  def self.post_template
    I18n.t("category.post_template", replace_paragraph: I18n.t("category.replace_paragraph"))
  end

  def create_category_definition
    t = Topic.new(title: I18n.t("category.topic_prefix", category: name), user: user, pinned_at: Time.now, category_id: id)
    t.skip_callbacks = true
    t.save!
    update_column(:topic_id, t.id)
    t.posts.create(raw: post_template, user: user)
  end

  def topic_url
    topic_only_relative_url.try(:relative_url)
  end

  def ensure_slug
    if name.present?
      self.name.strip!
      self.slug = Slug.for(name)

      return if self.slug.blank?

      # If a category with that slug already exists, set the slug to nil so the category can be found
      # another way.
      category = Category.where(slug: self.slug)
      category = category.where("id != ?", id) if id.present?
      self.slug = '' if category.exists?
    end
  end

  # Categories are cached in the site json, so the caches need to be
  # invalidated whenever the category changes.
  def invalidate_site_cache
    Site.invalidate_cache
  end

  def publish_categories_list
    MessageBus.publish('/categories', {categories: ActiveModel::ArraySerializer.new(Category.latest).as_json})
  end

  def parent_category_validator
    if parent_category_id
      errors.add(:parent_category_id, I18n.t("category.errors.self_parent")) if parent_category_id == id

      grandfather_id = Category.where(id: parent_category_id).pluck(:parent_category_id).first
      errors.add(:base, I18n.t("category.errors.depth")) if grandfather_id
    end
  end

  def group_names=(names)
    # this line bothers me, destroying in AR can not seem to be queued, thinking of extending it
    category_groups.destroy_all unless new_record?
    ids = Group.where(name: names.split(",")).pluck(:id)
    ids.each do |id|
      category_groups.build(group_id: id)
    end
  end

  # will reset permission on a topic to a particular
  # set.
  #
  # Available permissions are, :full, :create_post, :readonly
  #   hash can be:
  #
  # :everyone => :full - everyone has everything
  # :everyone => :readonly, :staff => :full
  # 7 => 1  # you can pass a group_id and permission id
  def set_permissions(permissions)
    self.read_restricted, @permissions = Category.resolve_permissions(permissions)

    # Ideally we can just call .clear here, but it runs SQL, we only want to run it
    # on save.
  end

  def permissions=(permissions)
    set_permissions(permissions)
  end

  def apply_permissions
    if @permissions
      category_groups.destroy_all
      @permissions.each do |group_id, permission_type|
        category_groups.build(group_id: group_id, permission_type: permission_type)
      end
      @permissions = nil
    end
  end

  def secure_group_ids
    if self.read_restricted?
      groups.pluck("groups.id")
    end
  end

  def update_latest
    latest_post_id = Post
                        .order("posts.created_at desc")
                        .where("NOT hidden")
                        .joins("join topics on topics.id = topic_id")
                        .where("topics.category_id = :id", id: self.id)
                        .limit(1)
                        .pluck("posts.id")
                        .first

    latest_topic_id = Topic
                        .order("topics.created_at desc")
                        .where("visible")
                        .where("topics.category_id = :id", id: self.id)
                        .limit(1)
                        .pluck("topics.id")
                        .first

    self.update_attributes(latest_topic_id: latest_topic_id, latest_post_id: latest_post_id)
  end

  def self.resolve_permissions(permissions)
    read_restricted = true

    everyone = Group::AUTO_GROUPS[:everyone]
    full = CategoryGroup.permission_types[:full]

    mapped = permissions.map do |group,permission|
      group = group.id if Group === group

      # subtle, using Group[] ensures the group exists in the DB
      group = Group[group.to_sym].id unless Fixnum === group
      permission = CategoryGroup.permission_types[permission] unless Fixnum === permission

      [group, permission]
    end

    mapped.each do |group, permission|
      if group == everyone && permission == full
        return [false, []]
      end

      read_restricted = false if group == everyone
    end

    [read_restricted, mapped]
  end
end

# == Schema Information
#
# Table name: categories
#
#  id              :integer          not null, primary key
#  name            :string(50)       not null
#  color           :string(6)        default("AB9364"), not null
#  topic_id        :integer
#  topic_count     :integer          default(0), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  user_id         :integer          not null
#  topics_year     :integer
#  topics_month    :integer
#  topics_week     :integer
#  slug            :string(255)      not null
#  description     :text
#  text_color      :string(6)        default("FFFFFF"), not null
#  hotness         :float            default(5.0), not null
#  read_restricted :boolean          default(FALSE), not null
#  auto_close_days :float
#
# Indexes
#
#  index_categories_on_forum_thread_count  (topic_count)
#  index_categories_on_name                (name) UNIQUE
#

