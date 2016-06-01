require_dependency 'distributed_cache'
require_dependency 'sass/discourse_stylesheets'

class Category < ActiveRecord::Base

  include Positionable
  include HasCustomFields
  include CategoryHashtag

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

  validate :email_in_validator

  validate :ensure_slug
  before_save :apply_permissions
  before_save :downcase_email
  before_save :downcase_name
  after_create :create_category_definition

  after_save :publish_category
  after_destroy :publish_category_deletion

  after_update :rename_category_definition, if: :name_changed?

  after_create :delete_category_permalink
  after_update :create_category_permalink, if: :slug_changed?

  after_save :publish_discourse_stylesheet

  has_one :category_search_data
  belongs_to :parent_category, class_name: 'Category'
  has_many :subcategories, class_name: 'Category', foreign_key: 'parent_category_id'

  has_many :category_tags
  has_many :tags, through: :category_tags

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
  attr_accessor :displayable_topics, :permission, :subcategory_ids, :notification_level, :has_children

  def self.last_updated_at
    order('updated_at desc').limit(1).pluck(:updated_at).first.to_i
  end

  def self.scoped_to_permissions(guardian, permission_types)
    if guardian && guardian.is_admin?
      all
    elsif !guardian || guardian.anonymous?
      if permission_types.include?(:readonly)
        where("NOT categories.read_restricted")
      else
        where("1 = 0")
      end
    else
      permission_types = permission_types.map{ |permission_type|
        CategoryGroup.permission_types[permission_type]
      }
      where("categories.id in (
                  SELECT cg.category_id FROM category_groups cg
                    WHERE permission_type in (:permissions) AND
                    (
                      group_id IN (
                        SELECT g.group_id FROM group_users g where g.user_id = :user_id
                      )
                    )
                )
                OR
                categories.id in (
                  SELECT cg.category_id FROM category_groups cg
                    WHERE permission_type in (:permissions) AND group_id = :everyone
                  )
                OR
                categories.id NOT in (SELECT cg.category_id FROM category_groups cg)
            ", permissions: permission_types,
               user_id: guardian.user.id,
               everyone: Group[:everyone].id)
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
    if has_attribute?("topic_slug")
      Topic.relative_url(topic_id, read_attribute(:topic_slug))
    else
      topic_only_relative_url.try(:relative_url)
    end
  end

  def description_text
    return nil unless description

    @@cache ||= LruRedux::ThreadSafeCache.new(1000)
    @@cache.getset(self.description) do
      Nokogiri::HTML(self.description).text
    end

  end

  def duplicate_slug?
    Category.where(slug: self.slug, parent_category_id: parent_category_id).where.not(id: id).any?
  end

  def ensure_slug
    return unless name.present?

    self.name.strip!

    if slug.present?
      # santized custom slug
      self.slug = Slug.sanitize(slug)
      errors.add(:slug, 'is already in use') if duplicate_slug?
    else
      # auto slug
      self.slug = Slug.for(name, '')
      self.slug = '' if duplicate_slug?
    end
    # only allow to use category itself id. new_record doesn't have a id.
    unless new_record?
      match_id = /^(\d+)-category/.match(self.slug)
      errors.add(:slug, :invalid) if match_id && match_id[1] && match_id[1] != self.id.to_s
    end
  end

  def slug_for_url
    slug.present? ? self.slug : "#{self.id}-category"
  end

  def publish_category
    group_ids = self.groups.pluck(:id) if self.read_restricted
    MessageBus.publish('/categories', {categories: ActiveModel::ArraySerializer.new([self]).as_json}, group_ids: group_ids)
  end

  def publish_category_deletion
    MessageBus.publish('/categories', {deleted_categories: [self.id]})
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

  def permissions_params
    hash = {}
    category_groups.includes(:group).each do |category_group|
      hash[category_group.group_name] = category_group.permission_type
    end
    hash
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

  def allowed_tags=(tag_names_arg)
    tag_names = DiscourseTagging.tags_for_saving(tag_names_arg, Guardian.new(Discourse.system_user)) || []
    if self.tags.pluck(:name).sort != tag_names.sort
      self.tags = Tag.where(name: tag_names).all
      if self.tags.size < tag_names.size
        new_tag_names = tag_names - self.tags.map(&:name)
        new_tag_names.each do |name|
          self.tags << Tag.create(name: name)
        end
      end
    end
  end

  def downcase_email
    self.email_in = (email_in || "").strip.downcase.presence
  end

  def email_in_validator
    return if self.email_in.blank?
    email_in.split("|").each do |email|
      if !Email.is_valid?(email)
        self.errors.add(:base, I18n.t('category.errors.invalid_email_in', email: email))
      elsif group = Group.find_by_email(email)
        self.errors.add(:base, I18n.t('category.errors.email_already_used_in_group', email: email, group_name: group.name))
      elsif category = Category.where.not(id: self.id).find_by_email(email)
        self.errors.add(:base, I18n.t('category.errors.email_already_used_in_category', email: email, category_name: category.name))
      end
    end
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

  def self.query_category(slug_or_id, parent_category_id)
    self.where(slug: slug_or_id, parent_category_id: parent_category_id).includes(:featured_users).first ||
    self.where(id: slug_or_id.to_i, parent_category_id: parent_category_id).includes(:featured_users).first
  end

  def self.find_by_email(email)
    self.where("string_to_array(email_in, '|') @> ARRAY[?]", Email.downcase(email)).first
  end

  def has_children?
    @has_children ||= (id && Category.where(parent_category_id: id).exists?) ? :true : :false
    @has_children == :true
  end

  def uncategorized?
    id == SiteSetting.uncategorized_category_id
  end

  @@url_cache = DistributedCache.new('category_url')

  after_save do
    # parent takes part in url calculation
    # any change could invalidate multiples
    @@url_cache.clear
  end

  def full_slug(separator = "-")
    url[3..-1].gsub("/", separator)
  end

  def url
    url = @@url_cache[self.id]
    unless url
      url = "#{Discourse.base_uri}/c"
      url << "/#{parent_category.slug}" if parent_category_id
      url << "/#{slug}"
      url.freeze

      @@url_cache[self.id] = url
    end

    url
  end

  def url_with_id
    self.parent_category ? "#{url}/#{self.id}" : "#{Discourse.base_uri}/c/#{self.id}-#{self.slug}"
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

  def create_category_permalink
    old_slug = changed_attributes["slug"]
    if self.parent_category
      Permalink.create(url: "c/#{self.parent_category.slug}/#{old_slug}", category_id: id)
    else
      Permalink.create(url: "c/#{old_slug}", category_id: id)
    end
  end

  def delete_category_permalink
    if self.parent_category
      permalink = Permalink.find_by_url("c/#{self.parent_category.slug}/#{slug}")
    else
      permalink = Permalink.find_by_url("c/#{slug}")
    end
    permalink.destroy if permalink
  end

  def publish_discourse_stylesheet
    DiscourseStylesheets.cache.clear
  end

  def self.find_by_slug(category_slug, parent_category_slug=nil)
    if parent_category_slug
      parent_category_id = self.where(slug: parent_category_slug, parent_category_id: nil).pluck(:id).first
      self.where(slug: category_slug, parent_category_id: parent_category_id).first
    else
      self.where(slug: category_slug, parent_category_id: nil).first
    end
  end
end

# == Schema Information
#
# Table name: categories
#
#  id                            :integer          not null, primary key
#  name                          :string(50)       not null
#  color                         :string(6)        default("AB9364"), not null
#  topic_id                      :integer
#  topic_count                   :integer          default(0), not null
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#  user_id                       :integer          not null
#  topics_year                   :integer          default(0)
#  topics_month                  :integer          default(0)
#  topics_week                   :integer          default(0)
#  slug                          :string           not null
#  description                   :text
#  text_color                    :string(6)        default("FFFFFF"), not null
#  read_restricted               :boolean          default(FALSE), not null
#  auto_close_hours              :float
#  post_count                    :integer          default(0), not null
#  latest_post_id                :integer
#  latest_topic_id               :integer
#  position                      :integer
#  parent_category_id            :integer
#  posts_year                    :integer          default(0)
#  posts_month                   :integer          default(0)
#  posts_week                    :integer          default(0)
#  email_in                      :string
#  email_in_allow_strangers      :boolean          default(FALSE)
#  topics_day                    :integer          default(0)
#  posts_day                     :integer          default(0)
#  logo_url                      :string
#  background_url                :string
#  allow_badges                  :boolean          default(TRUE), not null
#  name_lower                    :string(50)       not null
#  auto_close_based_on_last_post :boolean          default(FALSE)
#  topic_template                :text
#  suppress_from_homepage        :boolean          default(FALSE)
#  contains_messages             :boolean
#
# Indexes
#
#  index_categories_on_email_in     (email_in) UNIQUE
#  index_categories_on_topic_count  (topic_count)
#  unique_index_categories_on_name  (name) UNIQUE
#
