require_dependency 'topic_list_responder'
require_dependency 'topics_bulk_action'
require_dependency 'topic_query'

class TagsController < ::ApplicationController
  include TopicListResponder

  before_action :ensure_tags_enabled

  skip_before_action :check_xhr, only: [:tag_feed, :show, :index]
  before_action :ensure_logged_in, except: [
    :index,
    :show,
    :tag_feed,
    :search,
    :check_hashtag,
    Discourse.anonymous_filters.map { |f| :"show_#{f}" }
  ].flatten
  before_action :set_category_from_params, except: [:index, :update, :destroy, :tag_feed, :search, :notifications, :update_notifications]

  def index
    categories = Category.where("id in (select category_id from category_tags)")
      .where("id in (?)", guardian.allowed_category_ids)
      .preload(:tags)
    category_tag_counts = categories.map do |c|
      h = Tag.category_tags_by_count_query(c, limit: 300).count(Tag::COUNT_ARG)
      h.merge!(c.tags.where.not(name: h.keys).inject({}) { |sum, t| sum[t.name] = 0; sum }) # unused tags
      { id: c.id, tags: self.class.tag_counts_json(h) }
    end

    tag_counts = self.class.tags_by_count(guardian, limit: 300).count(Tag::COUNT_ARG)
    @tags = self.class.tag_counts_json(tag_counts)

    @description_meta = I18n.t("tags.title")
    @title = @description_meta

    respond_to do |format|
      format.html do
        render :index
      end
      format.json do
        render json: {
          tags: @tags,
          extras: { categories: category_tag_counts }
        }
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

      if @list.topics.size == 0 && params[:tag_id] != 'none' && !Tag.where(name: @tag_id).exists?
        permalink_redirect_or_not_found
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

  def destroy
    guardian.ensure_can_admin_tags!
    tag_name = params[:tag_id]
    TopicCustomField.transaction do
      Tag.find_by_name(tag_name).destroy
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
    category = params[:categoryId] ? Category.find_by_id(params[:categoryId]) : nil

    tags_with_counts = DiscourseTagging.filter_allowed_tags(
      Tag.tags_by_count_query(params.slice(:limit)),
      guardian,
      for_input: params[:filterForInput],
      term: params[:q],
      category: category,
      selected_tags: params[:selected_tags]
    )

    tags = tags_with_counts.count(Tag::COUNT_ARG).map { |t, c| { id: t, text: t, count: c } }

    json_response = { results: tags }

    if Tag.where(name: params[:q]).exists? && !tags.find { |h| h[:id] == params[:q] }
      # filter_allowed_tags determined that the tag entered is not allowed
      json_response[:forbidden] = params[:q]
    end

    render json: json_response
  end

  def notifications
    tag = Tag.find_by_name(params[:tag_id])
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
    tag_values = params[:tag_values].each(&:downcase!)

    valid_tags = Tag.where(name: tag_values).map do |tag|
      { value: tag.name, url: tag.full_url }
    end.compact

    render json: { valid: valid_tags }
  end

  private

    def ensure_tags_enabled
      raise Discourse::NotFound unless SiteSetting.tagging_enabled?
    end

    def self.tags_by_count(guardian, opts = {})
      guardian.filter_allowed_categories(Tag.tags_by_count_query(opts))
    end

    def self.tag_counts_json(tag_counts)
      tag_counts.map { |t, c| { id: t, text: t, count: c } }
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

      url = if action == :prev
        public_send(method, opts.merge(prev_page_params(opts)))
      else # :next
        public_send(method, opts.merge(next_page_params(opts)))
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
      options[:slow_platform] = true if slow_platform?

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
