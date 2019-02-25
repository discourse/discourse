require_dependency 'topic_list_responder'
require_dependency 'topics_bulk_action'
require_dependency 'topic_query'

class TagsController < ::ApplicationController
  include TopicListResponder

  before_action :ensure_tags_enabled

  requires_login except: [
    :index,
    :show,
    :tag_feed,
    :search,
    :check_hashtag,
    Discourse.anonymous_filters.map { |f| :"show_#{f}" }
  ].flatten

  skip_before_action :check_xhr, only: [:tag_feed, :show, :index]

  before_action :set_category_from_params, except: [:index, :update, :destroy,
    :tag_feed, :search, :notifications, :update_notifications, :personal_messages]

  def index
    @description_meta = I18n.t("tags.title")
    @title = @description_meta

    respond_to do |format|

      format.html do
        render :index
      end

      format.json do
        show_all_tags = guardian.can_admin_tags? && guardian.is_admin?

        if SiteSetting.tags_listed_by_group
          ungrouped_tags = Tag.where("tags.id NOT IN (SELECT tag_id FROM tag_group_memberships)")
          ungrouped_tags = ungrouped_tags.where("tags.topic_count > 0") unless show_all_tags

          grouped_tag_counts = TagGroup.visible(guardian).order('name ASC').includes(:tags).map do |tag_group|
            { id: tag_group.id, name: tag_group.name, tags: self.class.tag_counts_json(tag_group.tags) }
          end

          render json: {
            tags: self.class.tag_counts_json(ungrouped_tags),
            extras: { tag_groups: grouped_tag_counts }
          }
        else
          tags = show_all_tags ? Tag.all : Tag.where("tags.topic_count > 0")
          unrestricted_tags = DiscourseTagging.filter_visible(tags, guardian)

          categories = Category.where("id IN (SELECT category_id FROM category_tags)")
            .where("id IN (?)", guardian.allowed_category_ids)
            .includes(:tags)

          category_tag_counts = categories.map do |c|
            { id: c.id, tags: self.class.tag_counts_json(c.tags) }
          end

          render json: {
            tags: self.class.tag_counts_json(unrestricted_tags),
            extras: { categories: category_tag_counts }
          }
        end
      end
    end
  end

  Discourse.filters.each do |filter|
    define_method("show_#{filter}") do
      @tag_id = params[:tag_id].force_encoding("UTF-8")
      @additional_tags = params[:additional_tag_ids].to_s.split('/').map { |t| t.force_encoding("UTF-8") }

      list_opts = build_topic_list_options

      @list = TopicQuery.new(current_user, list_opts).public_send("list_#{filter}")

      @list.draft_key = Draft::NEW_TOPIC
      @list.draft_sequence = DraftSequence.current(current_user, Draft::NEW_TOPIC)
      @list.draft = Draft.get(current_user, @list.draft_key, @list.draft_sequence) if current_user

      @list.more_topics_url = construct_url_with(:next, list_opts)
      @list.prev_topics_url = construct_url_with(:prev, list_opts)
      @rss = "tag"
      @description_meta = I18n.t("rss_by_tag", tag: tag_params.join(' & '))
      @title = @description_meta

      path_name = url_method(params.slice(:category, :parent_category))
      canonical_url "#{Discourse.base_url_no_prefix}#{public_send(path_name, *(params.slice(:parent_category, :category, :tag_id).values.map { |t| t.force_encoding("UTF-8") }))}"

      if @list.topics.size == 0 && params[:tag_id] != 'none' && !Tag.where_name(@tag_id).exists?
        raise Discourse::NotFound.new("tag not found", check_permalinks: true)
      else
        respond_with_list(@list)
      end
    end
  end

  def show
    show_latest
  end

  def update
    guardian.ensure_can_admin_tags!

    tag = Tag.find_by_name(params[:tag_id])
    raise Discourse::NotFound if tag.nil?

    new_tag_name = DiscourseTagging.clean_tag(params[:tag][:id])
    tag.name = new_tag_name
    if tag.save
      StaffActionLogger.new(current_user).log_custom('renamed_tag', previous_value: params[:tag_id], new_value: new_tag_name)
      render json: { tag: { id: new_tag_name } }
    else
      render_json_error tag.errors.full_messages
    end
  end

  def upload
    guardian.ensure_can_admin_tags!

    file = params[:file] || params[:files].first

    hijack do
      begin
        Tag.transaction do
          CSV.foreach(file.tempfile) do |row|
            raise Discourse::InvalidParameters.new(I18n.t("tags.upload_row_too_long")) if row.length > 2

            tag_name = DiscourseTagging.clean_tag(row[0])
            tag_group_name = row[1] || nil

            tag = Tag.find_by_name(tag_name) || Tag.create!(name: tag_name)

            if tag_group_name
              tag_group = TagGroup.find_by(name: tag_group_name) || TagGroup.create!(name: tag_group_name)
              tag.tag_groups << tag_group unless tag.tag_groups.include?(tag_group)
            end
          end
        end
        render json: success_json
      rescue Discourse::InvalidParameters => e
        render json: failed_json.merge(errors: [e.message]), status: 422
      end
    end
  end

  def list_unused
    guardian.ensure_can_admin_tags!
    render json: { tags: Tag.unused.pluck(:name) }
  end

  def destroy_unused
    guardian.ensure_can_admin_tags!
    tags = Tag.unused
    StaffActionLogger.new(current_user).log_custom('deleted_unused_tags', tags: tags.pluck(:name))
    tags.destroy_all
    render json: success_json
  end

  def destroy
    guardian.ensure_can_admin_tags!
    tag_name = params[:tag_id]
    tag = Tag.find_by_name(tag_name)
    raise Discourse::NotFound if tag.nil?

    TopicCustomField.transaction do
      tag.destroy
      StaffActionLogger.new(current_user).log_custom('deleted_tag', subject: tag_name)
    end
    render json: success_json
  end

  def tag_feed
    discourse_expires_in 1.minute

    tag_id = params[:tag_id]
    @link = "#{Discourse.base_url}/tags/#{tag_id}"
    @description = I18n.t("rss_by_tag", tag: tag_id)
    @title = "#{SiteSetting.title} - #{@description}"
    @atom_link = "#{Discourse.base_url}/tags/#{tag_id}.rss"

    query = TopicQuery.new(current_user, tags: [tag_id])
    latest_results = query.latest_results
    @topic_list = query.create_list(:by_tag, {}, latest_results)

    render 'list/list', formats: [:rss]
  end

  def search
    clean_name = DiscourseTagging.clean_tag(params[:q])
    category = params[:categoryId] ? Category.find_by_id(params[:categoryId]) : nil

    # Prioritize exact matches when ordering
    order_query = Tag.sanitize_sql_for_order(
      ["lower(name) = lower(?) DESC, topic_count DESC", clean_name]
    )

    tags_with_counts = DiscourseTagging.filter_allowed_tags(
      Tag.order(order_query).limit(params[:limit]),
      guardian,
      for_input: params[:filterForInput],
      term: clean_name,
      category: category,
      selected_tags: params[:selected_tags]
    )

    tags = self.class.tag_counts_json(tags_with_counts)

    json_response = { results: tags }

    if !tags.find { |h| h[:id].downcase == clean_name.downcase } && tag = Tag.where_name(clean_name).first
      # filter_allowed_tags determined that the tag entered is not allowed
      json_response[:forbidden] = params[:q]

      category_names = tag.categories.where(id: guardian.allowed_category_ids).pluck(:name)
      category_names += Category.joins(tag_groups: :tags).where(id: guardian.allowed_category_ids, "tags.id": tag.id).pluck(:name)

      if category_names.present?
        category_names.uniq!
        json_response[:forbidden_message] = I18n.t(
          "tags.forbidden.restricted_to",
          count: category_names.count,
          tag_name: tag.name,
          category_names: category_names.join(", ")
        )
      else
        json_response[:forbidden_message] = I18n.t("tags.forbidden.in_this_category", tag_name: tag.name)
      end
    end

    render json: json_response
  end

  def notifications
    tag = Tag.where_name(params[:tag_id]).first
    raise Discourse::NotFound unless tag
    level = tag.tag_users.where(user: current_user).first.try(:notification_level) || TagUser.notification_levels[:regular]
    render json: { tag_notification: { id: tag.name, notification_level: level.to_i } }
  end

  def update_notifications
    tag = Tag.find_by_name(params[:tag_id])
    raise Discourse::NotFound unless tag
    level = params[:tag_notification][:notification_level].to_i
    TagUser.change(current_user.id, tag.id, level)
    render json: { notification_level: level }
  end

  def check_hashtag
    valid_tags = Tag.where_name(params[:tag_values]).map do |tag|
      { value: tag.name, url: tag.full_url }
    end.compact

    render json: { valid: valid_tags }
  end

  def personal_messages
    guardian.ensure_can_tag_pms!
    allowed_user = fetch_user_from_params
    raise Discourse::NotFound if allowed_user.blank?
    raise Discourse::NotFound if current_user.id != allowed_user.id && !@guardian.is_admin?
    pm_tags = Tag.pm_tags(guardian: guardian, allowed_user: allowed_user)

    render json: { tags: pm_tags }
  end

  private

  def ensure_tags_enabled
    raise Discourse::NotFound unless SiteSetting.tagging_enabled?
  end

  def self.tag_counts_json(tags)
    tags.map { |t| { id: t.name, text: t.name, count: t.topic_count, pm_count: t.pm_topic_count } }
  end

  def set_category_from_params
    slug_or_id = params[:category]
    return true if slug_or_id.nil?

    if slug_or_id == 'none' && params[:parent_category]
      @filter_on_category = Category.query_category(params[:parent_category], nil)
      params[:no_subcategories] = 'true'
    else
      parent_slug_or_id = params[:parent_category]

      parent_category_id = nil
      if parent_slug_or_id.present?
        parent_category_id = Category.query_parent_category(parent_slug_or_id)
        category_redirect_or_not_found && (return) if parent_category_id.blank?
      end

      @filter_on_category = Category.query_category(slug_or_id, parent_category_id)
    end

    category_redirect_or_not_found && (return) if !@filter_on_category

    guardian.ensure_can_see!(@filter_on_category)
  end

  # TODO: this is duplication of ListController
  def page_params(opts = nil)
    opts ||= {}
    route_params = { format: 'json' }
    route_params[:category]        = @filter_on_category.slug_for_url                 if @filter_on_category
    route_params[:parent_category] = @filter_on_category.parent_category.slug_for_url if @filter_on_category && @filter_on_category.parent_category
    route_params[:order]           = opts[:order]      if opts[:order].present?
    route_params[:ascending]       = opts[:ascending]  if opts[:ascending].present?
    route_params
  end

  def next_page_params(opts = nil)
    page_params(opts).merge(page: params[:page].to_i + 1)
  end

  def prev_page_params(opts = nil)
    pg = params[:page].to_i
    if pg > 1
      page_params(opts).merge(page: pg - 1)
    else
      page_params(opts).merge(page: nil)
    end
  end

  def url_method(opts = {})
    if opts[:parent_category] && opts[:category]
      "tag_parent_category_category_#{action_name}_path"
    elsif opts[:category]
      "tag_category_#{action_name}_path"
    else
      "tag_#{action_name}_path"
    end
  end

  def construct_url_with(action, opts)
    method = url_method(opts)

    begin
      url = if action == :prev
        public_send(method, opts.merge(prev_page_params(opts)))
      else # :next
        public_send(method, opts.merge(next_page_params(opts)))
      end
    rescue ActionController::UrlGenerationError
      raise Discourse::NotFound
    end
    url.sub('.json?', '?')
  end

  def build_topic_list_options
    options = {
      page: params[:page],
      topic_ids: param_to_integer_list(:topic_ids),
      exclude_category_ids: params[:exclude_category_ids],
      category: @filter_on_category ? @filter_on_category.id : params[:category],
      order: params[:order],
      ascending: params[:ascending],
      min_posts: params[:min_posts],
      max_posts: params[:max_posts],
      status: params[:status],
      filter: params[:filter],
      state: params[:state],
      search: params[:search],
      q: params[:q]
    }
    options[:no_subcategories] = true if params[:no_subcategories] == 'true'

    if params[:tag_id] == 'none'
      options[:no_tags] = true
    else
      options[:tags] = tag_params
      options[:match_all_tags] = true
    end

    options
  end

  def category_redirect_or_not_found
    # automatic redirects for renamed categories
    url = params[:parent_category] ? "c/#{params[:parent_category]}/#{params[:category]}" : "c/#{params[:category]}"
    permalink = Permalink.find_by_url(url)

    if permalink.present? && permalink.category_id
      redirect_to "#{Discourse::base_uri}/tags#{permalink.target_url}/#{params[:tag_id]}", status: :moved_permanently
    else
      # redirect to 404
      raise Discourse::NotFound
    end
  end

  def tag_params
    [@tag_id].concat(Array(@additional_tags))
  end
end
