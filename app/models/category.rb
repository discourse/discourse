class Category < ActiveRecord::Base

  include Positionable
  include HasCustomFields

  belongs_to :topic, dependent: :destroy
  belongs_to :topic_only_relative_url,
              -> { select "id, title, slug" },
              class_name: "Topic",
              foreign_key: "topic_id"

  belongs_to :user
  belongs_to :latest_post, class_name: "Post"

  has_many :topics
  has_many :category_featured_topics
  has_many :featured_topics, through: :category_featured_topics, source: :topic

  has_many :category_featured_users
  has_many :featured_users, through: :category_featured_users, source: :user

  has_many :category_groups, dependent: :destroy
  has_many :groups, through: :category_groups

  validates :user_id, presence: true
  validates :name, if: Proc.new { |c| c.new_record? || c.name_changed? },
                   presence: true,
                   uniqueness: { scope: :parent_category_id, case_sensitive: false },
                   length: { in: 1..50 }
  validate :parent_category_validator

  before_validation :ensure_slug
  before_save :apply_permissions
  before_save :downcase_email
  before_save :downcase_name
  after_create :create_category_definition
  after_create :publish_categories_list
  after_destroy :publish_categories_list
  after_update :rename_category_definition, if: :name_changed?

  has_one :category_search_data
  belongs_to :parent_category, class_name: 'Category'
  has_many :subcategories, class_name: 'Category', foreign_key: 'parent_category_id'

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
  attr_accessor :displayable_topics, :permission, :subcategory_ids, :notification_level

  def self.last_updated_at
    order('updated_at desc').limit(1).pluck(:updated_at).first.to_i
  end

  def self.scoped_to_permissions(guardian, permission_types)
    if guardian && guardian.is_staff?
      all
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

  def self.update_stats
    topics_with_post_count = Topic
                              .select("topics.category_id, COUNT(*) topic_count, SUM(topics.posts_count) post_count")
                              .where("topics.id NOT IN (select cc.topic_id from categories cc WHERE topic_id IS NOT NULL)")
                              .group("topics.category_id")
                              .visible.to_sql

    Category.exec_sql <<SQL
    UPDATE categories c
    SET   topic_count = x.topic_count,
          post_count = x.post_count
    FROM (#{topics_with_post_count}) x
    WHERE x.category_id = c.id AND
          (c.topic_count <> x.topic_count OR c.post_count <> x.post_count)

SQL

    # Yes, there are a lot of queries happening below.
    # Performing a lot of queries is actually faster than using one big update
    # statement with sub-selects on large databases with many categories,
    # topics, and posts.
    #
    # The old method with the one query is here:
    # https://github.com/discourse/discourse/blob/5f34a621b5416a53a2e79a145e927fca7d5471e8/app/models/category.rb
    #
    # If you refactor this, test performance on a large database.

    Category.all.each do |c|
      topics = c.topics.visible
      topics = topics.where(['topics.id <> ?', c.topic_id]) if c.topic_id
      c.topics_year  = topics.created_since(1.year.ago).count
      c.topics_month = topics.created_since(1.month.ago).count
      c.topics_week  = topics.created_since(1.week.ago).count
      c.topics_day   = topics.created_since(1.day.ago).count

      posts = c.visible_posts
      c.posts_year  = posts.created_since(1.year.ago).count
      c.posts_month = posts.created_since(1.month.ago).count
      c.posts_week  = posts.created_since(1.week.ago).count
      c.posts_day   = posts.created_since(1.day.ago).count

      c.save if c.changed?
    end
  end


  def visible_posts
    query = Post.joins(:topic)
                .where(['topics.category_id = ?', self.id])
                .where('topics.visible = true')
                .where('posts.deleted_at IS NULL')
                .where('posts.user_deleted = false')
    self.topic_id ? query.where(['topics.id <> ?', self.topic_id]) : query
  end


  # Internal: Generate the text of post prompting to enter category
  # description.
  def self.post_template
    I18n.t("category.post_template", replace_paragraph: I18n.t("category.replace_paragraph"))
  end

  def create_category_definition
    t = Topic.new(title: I18n.t("category.topic_prefix", category: name), user: user, pinned_at: Time.now, category_id: id)
    t.skip_callbacks = true
    t.ignore_category_auto_close = true
    t.set_auto_close(nil)
    t.save!(validate: false)
    update_column(:topic_id, t.id)
    t.posts.create(raw: post_template, user: user)
  end

  def topic_url
    topic_only_relative_url.try(:relative_url)
  end

  def description_text
    return nil unless description

    @@cache ||= LruRedux::ThreadSafeCache.new(100)
    @@cache.getset(self.description) do
      Nokogiri::HTML(self.description).text
    end

  end

  def ensure_slug
    if name.present?
      self.name.strip!
      self.slug = Slug.for(name)

      return if self.slug.blank?

      # If a category with that slug already exists, set the slug to nil so the category can be found
      # another way.
      category = Category.where(slug: self.slug, parent_category_id: parent_category_id)
      category = category.where("id != ?", id) if id.present?
      self.slug = '' if category.exists?
    end
  end

  def slug_for_url
    slug.present? ? self.slug : "#{self.id}-category"
  end

  def publish_categories_list
    MessageBus.publish('/categories', {categories: ActiveModel::ArraySerializer.new(Category.latest).as_json})
  end

  def parent_category_validator
    if parent_category_id
      errors.add(:base, I18n.t("category.errors.self_parent")) if parent_category_id == id
      errors.add(:base, I18n.t("category.errors.uncategorized_parent")) if uncategorized?

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

  def downcase_email
    self.email_in = email_in.downcase if self.email_in
  end

  def downcase_name
    self.name_lower = name.downcase if self.name
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
      group = group.id if group.is_a?(Group)

      # subtle, using Group[] ensures the group exists in the DB
      group = Group[group.to_sym].id unless group.is_a?(Fixnum)
      permission = CategoryGroup.permission_types[permission] unless permission.is_a?(Fixnum)

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

  def self.query_parent_category(parent_slug)
    self.where(slug: parent_slug, parent_category_id: nil).pluck(:id).first ||
    self.where(id: parent_slug.to_i).pluck(:id).first
  end

  def self.query_category(slug, parent_category_id)
    self.where(slug: slug, parent_category_id: parent_category_id).includes(:featured_users).first ||
    self.where(id: slug.to_i, parent_category_id: parent_category_id).includes(:featured_users).first
  end

  def self.find_by_email(email)
    self.find_by(email_in: Email.downcase(email))
  end

  def has_children?
    id && Category.where(parent_category_id: id).exists?
  end

  def uncategorized?
    id == SiteSetting.uncategorized_category_id
  end

  def url
    url = "/category"
    url << "/#{parent_category.slug}" if parent_category_id
    url << "/#{slug}"
  end

  # If the name changes, try and update the category definition topic too if it's
  # an exact match
  def rename_category_definition
    old_name = changed_attributes["name"]
    return unless topic.present?
    if topic.title == I18n.t("category.topic_prefix", category: old_name)
      topic.update_column(:title, I18n.t("category.topic_prefix", category: name))
    end
  end
end

# == Schema Information
#
# Table name: categories
#
#  id                       :integer          not null, primary key
#  name                     :string(50)       not null
#  color                    :string(6)        default("AB9364"), not null
#  topic_id                 :integer
#  topic_count              :integer          default(0), not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  user_id                  :integer          not null
#  topics_year              :integer          default(0)
#  topics_month             :integer          default(0)
#  topics_week              :integer          default(0)
#  slug                     :string(255)      not null
#  description              :text
#  text_color               :string(6)        default("FFFFFF"), not null
#  read_restricted          :boolean          default(FALSE), not null
#  auto_close_hours         :float
#  post_count               :integer          default(0), not null
#  latest_post_id           :integer
#  latest_topic_id          :integer
#  position                 :integer
#  parent_category_id       :integer
#  posts_year               :integer          default(0)
#  posts_month              :integer          default(0)
#  posts_week               :integer          default(0)
#  email_in                 :string(255)
#  email_in_allow_strangers :boolean          default(FALSE)
#  topics_day               :integer          default(0)
#  posts_day                :integer          default(0)
#  logo_url                 :string(255)
#  background_url           :string(255)
#  allow_badges             :boolean          default(TRUE), not null
#  name_lower               :string(50)       not null
#
# Indexes
#
#  index_categories_on_email_in     (email_in) UNIQUE
#  index_categories_on_topic_count  (topic_count)
#  unique_index_categories_on_name  (name) UNIQUE
#
