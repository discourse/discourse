class ListController < ApplicationController

  skip_before_filter :check_xhr

  @@categories = [
    # filtered topics lists
    Discourse.filters.map { |f| "#{f}_category".to_sym },
    Discourse.filters.map { |f| "#{f}_category_none".to_sym },
    # top summary
    :top_category,
    :top_category_none,
    # top pages (ie. with a period)
    TopTopic.periods.map { |p| "top_#{p}_category".to_sym },
    TopTopic.periods.map { |p| "top_#{p}_category_none".to_sym },
    # category feeds
    :category_feed,
  ].flatten

  before_filter :set_category, only: @@categories

  before_filter :ensure_logged_in, except: [
    :topics_by,
    # anonymous filters
    Discourse.anonymous_filters,
    Discourse.anonymous_filters.map { |f| "#{f}_feed".to_sym },
    # categories
    @@categories,
    # top
    :top,
    TopTopic.periods.map { |p| "top_#{p}".to_sym }
  ].flatten

  # Create our filters
  Discourse.filters.each do |filter|
    define_method(filter) do |options = nil|
      list_opts = build_topic_list_options
      list_opts.merge!(options) if options
      user = list_target_user
      list = TopicQuery.new(user, list_opts).public_send("list_#{filter}")
      list.more_topics_url = construct_url_with(filter, list_opts)
      if Discourse.anonymous_filters.include?(filter)
        @description = SiteSetting.site_description
        @rss = filter
      end
      respond(list)
    end

    define_method("#{filter}_category") do
      self.send(filter, { category: @category.id })
    end

    define_method("#{filter}_category_none") do
      self.send(filter, { category: @category.id, no_subcategories: true })
    end
  end

  Discourse.anonymous_filters.each do |filter|
    define_method("#{filter}_feed") do
      discourse_expires_in 1.minute

      @title = "#{filter.capitalize} Topics"
      @link = "#{Discourse.base_url}/#{filter}"
      @description = I18n.t("rss_description.#{filter}")
      @atom_link = "#{Discourse.base_url}/#{filter}.rss"
      @topic_list = TopicQuery.new.public_send("list_#{filter}")

      render 'list', formats: [:rss]
    end
  end

  [:topics_by, :private_messages, :private_messages_sent, :private_messages_unread].each do |action|
    define_method("#{action}") do
      list_opts = build_topic_list_options
      target_user = fetch_user_from_params
      guardian.ensure_can_see_private_messages!(target_user.id) unless action == :topics_by
      list = generate_list_for(action.to_s, target_user, list_opts)
      url_prefix = "topics" unless action == :topics_by
      url  = construct_url_with(action, list_opts, url_prefix)
      list.more_topics_url = url_for(url)
      respond(list)
    end
  end

  def category_feed
    guardian.ensure_can_see!(@category)
    discourse_expires_in 1.minute

    @title = @category.name
    @link = "#{Discourse.base_url}/category/#{@category.slug}"
    @description = "#{I18n.t('topics_in_category', category: @category.name)} #{@category.description}"
    @atom_link = "#{Discourse.base_url}/category/#{@category.slug}.rss"
    @topic_list = TopicQuery.new.list_new_in_category(@category)

    render 'list', formats: [:rss]
  end

  def popular_redirect
    # We've renamed popular to latest. Use a redirect until we're sure we can
    # safely remove this.
    redirect_to latest_path, :status => 301
  end

  def top(options = nil)
    discourse_expires_in 1.minute

    top_options = build_topic_list_options
    top_options.merge!(options) if options

    top = generate_top_lists(top_options)

    respond_to do |format|
      format.html do
        @top = top
        store_preloaded('top_lists', MultiJson.dump(TopListSerializer.new(top, scope: guardian, root: false)))
        render 'top'
      end
      format.json do
        render json: MultiJson.dump(TopListSerializer.new(top, scope: guardian, root: false))
      end
    end
  end

  def top_category
    options = { category: @category.id }
    top(options)
  end

  def top_category_none
    options = { category: @category.id, no_subcategories: true }
    top(options)
  end

  TopTopic.periods.each do |period|
    define_method("top_#{period}") do |options = nil|
      top_options = build_topic_list_options
      top_options.merge!(options) if options
      top_options[:per_page] = SiteSetting.topics_per_period_in_top_page
      user = list_target_user
      list = TopicQuery.new(user, top_options).public_send("list_top_#{period}")
      list.more_topics_url = construct_url_with(period, top_options, "top")
      respond(list)
    end

    define_method("top_#{period}_category") do
      self.send("top_#{period}", { category: @category.id })
    end

    define_method("top_#{period}_category_none") do
      self.send("top_#{period}", { category: @category.id, no_subcategories: true })
    end
  end

  protected

  def respond(list)
    discourse_expires_in 1.minute

    list.draft_key = Draft::NEW_TOPIC
    list.draft_sequence = DraftSequence.current(current_user, Draft::NEW_TOPIC)
    list.draft = Draft.get(current_user, list.draft_key, list.draft_sequence) if current_user

    respond_to do |format|
      format.html do
        @list = list
        store_preloaded('topic_list', MultiJson.dump(TopicListSerializer.new(list, scope: guardian)))
        render 'list'
      end
      format.json do
        render_serialized(list, TopicListSerializer)
      end
    end
  end

  def next_page_params(opts=nil)
    opts = opts || {}
    route_params = { format: 'json', page: params[:page].to_i + 1 }
    route_params[:sort_order] = opts[:sort_order] if opts[:sort_order].present?
    route_params[:sort_descending] = opts[:sort_descending] if opts[:sort_descending].present?
    route_params
  end

  private

  def set_category
    slug_or_id = params.fetch(:category)
    parent_slug_or_id = params[:parent_category]

    parent_category_id = nil
    if parent_slug_or_id.present?
      parent_category_id = Category.where(slug: parent_slug_or_id).pluck(:id).first ||
                           Category.where(id: parent_slug_or_id.to_i).pluck(:id).first
      raise Discourse::NotFound.new if parent_category_id.blank?
    end

    @category = Category.where(slug: slug_or_id, parent_category_id: parent_category_id).includes(:featured_users).first ||
                Category.where(id: slug_or_id.to_i, parent_category_id: parent_category_id).includes(:featured_users).first

    raise Discourse::NotFound.new if @category.blank?
  end

  def build_topic_list_options
    # html format means we need to parse exclude category (aka filter) from the site options top menu
    menu_items = SiteSetting.top_menu_items
    menu_item = menu_items.select { |item| item.query_should_exclude_category?(action_name, params[:format]) }.first

    # exclude_category = 1. from params / 2. parsed from top menu / 3. nil
    options = {
      page: params[:page],
      topic_ids: param_to_integer_list(:topic_ids),
      exclude_category: (params[:exclude_category] || menu_item.try(:filter)),
      category: params[:category],
      sort_order: params[:sort_order],
      sort_descending: params[:sort_descending],
      status: params[:status]
    }
    options[:no_subcategories] = true if params[:no_subcategories] == 'true'

    options
  end

  def list_target_user
    if params[:user_id] && guardian.is_staff?
      User.find(params[:user_id].to_i)
    else
      current_user
    end
  end

  def generate_list_for(action, target_user, opts)
    TopicQuery.new(current_user, opts).send("list_#{action}", target_user)
  end

  def construct_url_with(action, opts, url_prefix=nil)
    method = url_prefix.blank? ? "#{action}_path" : "#{url_prefix}_#{action}_path"
    public_send(method, opts.merge(next_page_params(opts)))
  end

  def generate_top_lists(options)
    top = {}
    options[:per_page] = SiteSetting.topics_per_period_in_top_summary
    topic_query = TopicQuery.new(current_user, options)

    if current_user.present?
      periods = [best_period_for(current_user.previous_visit_at)]
    else
      periods = TopTopic.periods
    end

    periods.each { |period| top[period] = topic_query.list_top_for(period) }

    top
  end

  def best_period_for(date)
    date ||= 1.year.ago
    return :yearly  if date < 180.days.ago
    return :monthly if date <  35.days.ago
    return :weekly  if date <   8.days.ago
    :daily
  end

end
