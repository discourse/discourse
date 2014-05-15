class ListController < ApplicationController

  skip_before_filter :check_xhr

  @@categories = [
    # filtered topics lists
    Discourse.filters.map { |f| "category_#{f}".to_sym },
    Discourse.filters.map { |f| "category_none_#{f}".to_sym },
    Discourse.filters.map { |f| "parent_category_category_#{f}".to_sym },
    Discourse.filters.map { |f| "parent_category_category_none_#{f}".to_sym },
    # top summaries
    :category_top,
    :category_none_top,
    :parent_category_category_top,
    # top pages (ie. with a period)
    TopTopic.periods.map { |p| "category_top_#{p}".to_sym },
    TopTopic.periods.map { |p| "category_none_top_#{p}".to_sym },
    TopTopic.periods.map { |p| "parent_category_category_top_#{p}".to_sym },
    # category feeds
    :category_feed,
  ].flatten

  before_filter :set_category, only: @@categories

  before_filter :ensure_logged_in, except: [
    :topics_by,
    # anonymous filters
    Discourse.anonymous_filters,
    Discourse.anonymous_filters.map { |f| "#{f}_feed".to_sym },
    # anonymous categorized filters
    Discourse.anonymous_filters.map { |f| "category_#{f}".to_sym },
    Discourse.anonymous_filters.map { |f| "category_none_#{f}".to_sym },
    Discourse.anonymous_filters.map { |f| "parent_category_category_#{f}".to_sym },
    Discourse.anonymous_filters.map { |f| "parent_category_category_none_#{f}".to_sym },
    # category feeds
    :category_feed,
    # top summaries
    :top,
    :category_top,
    :category_none_top,
    :parent_category_category_top,
    # top pages (ie. with a period)
    TopTopic.periods.map { |p| "top_#{p}".to_sym },
    TopTopic.periods.map { |p| "category_top_#{p}".to_sym },
    TopTopic.periods.map { |p| "category_none_top_#{p}".to_sym },
    TopTopic.periods.map { |p| "parent_category_category_top_#{p}".to_sym },
  ].flatten

  # Create our filters
  Discourse.filters.each do |filter|
    define_method(filter) do |options = nil|
      list_opts = build_topic_list_options
      list_opts.merge!(options) if options
      user = list_target_user

      if filter == :latest && params[:category].blank?
        list_opts[:no_definitions] = true
      end

      list = TopicQuery.new(user, list_opts).public_send("list_#{filter}")
      list.more_topics_url = construct_next_url_with(list_opts)
      list.prev_topics_url = construct_prev_url_with(list_opts)
      if Discourse.anonymous_filters.include?(filter)
        @description = SiteSetting.site_description
        @rss = filter
      end
      respond(list)
    end

    define_method("category_#{filter}") do
      self.send(filter, { category: @category.id })
    end

    define_method("category_none_#{filter}") do
      self.send(filter, { category: @category.id, no_subcategories: true })
    end

    define_method("parent_category_category_#{filter}") do
      self.send(filter, { category: @category.id })
    end

    define_method("parent_category_category_none_#{filter}") do
      self.send(filter, { category: @category.id })
    end
  end

  Discourse.anonymous_filters.each do |filter|
    define_method("#{filter}_feed") do
      discourse_expires_in 1.minute

      @title = "#{SiteSetting.title} - #{I18n.t("rss_description.#{filter}")}"
      @link = "#{Discourse.base_url}/#{filter}"
      @description = I18n.t("rss_description.#{filter}")
      @atom_link = "#{Discourse.base_url}/#{filter}.rss"
      @topic_list = TopicQuery.new(nil, order: 'activity').public_send("list_#{filter}")

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
      list.more_topics_url = url_for(construct_next_url_with(list_opts, url_prefix))
      list.prev_topics_url = url_for(construct_prev_url_with(list_opts, url_prefix))
      respond(list)
    end
  end

  def category_feed
    guardian.ensure_can_see!(@category)
    discourse_expires_in 1.minute

    @title = @category.name
    @link = "#{Discourse.base_url}/category/#{@category.slug_for_url}"
    @description = "#{I18n.t('topics_in_category', category: @category.name)} #{@category.description}"
    @atom_link = "#{Discourse.base_url}/category/#{@category.slug_for_url}.rss"
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

    top.draft_key = Draft::NEW_TOPIC
    top.draft_sequence = DraftSequence.current(current_user, Draft::NEW_TOPIC)
    top.draft = Draft.get(current_user, top.draft_key, top.draft_sequence) if current_user

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

  def category_top
    options = { category: @category.id }
    top(options)
  end

  def category_none_top
    options = { category: @category.id, no_subcategories: true }
    top(options)
  end

  def parent_category_category_top
    options = { category: @category.id }
    top(options)
  end

  TopTopic.periods.each do |period|
    define_method("top_#{period}") do |options = nil|
      top_options = build_topic_list_options
      top_options.merge!(options) if options
      top_options[:per_page] = SiteSetting.topics_per_period_in_top_page
      user = list_target_user
      list = TopicQuery.new(user, top_options).list_top_for(period)
      list.more_topics_url = construct_next_url_with(top_options)
      list.prev_topics_url = construct_prev_url_with(top_options)
      respond(list)
    end

    define_method("category_top_#{period}") do
      self.send("top_#{period}", { category: @category.id })
    end

    define_method("category_none_top_#{period}") do
      self.send("top_#{period}", { category: @category.id, no_subcategories: true })
    end

    define_method("parent_category_category_#{period}") do
      self.send("top_#{period}", { category: @category.id })
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


  private

  def page_params(opts = nil)
    opts ||= {}
    route_params = {format: 'json'}
    route_params[:category]        = @category.slug_for_url if @category
    route_params[:parent_category] = @category.parent_category.slug_for_url if @category && @category.parent_category
    route_params[:order]     = opts[:order] if opts[:order].present?
    route_params[:ascending] = opts[:ascending] if opts[:ascending].present?
    route_params
  end

  def set_category
    slug_or_id = params.fetch(:category)
    parent_slug_or_id = params[:parent_category]

    parent_category_id = nil
    if parent_slug_or_id.present?
      parent_category_id = Category.query_parent_category(parent_slug_or_id)
      raise Discourse::NotFound.new if parent_category_id.blank?
    end

    @category = Category.query_category(slug_or_id, parent_category_id)
    raise Discourse::NotFound.new if !@category

    @description_meta = @category.description
    guardian.ensure_can_see!(@category)
  end

  def build_topic_list_options
    # exclude_category = 1. from params / 2. parsed from top menu / 3. nil
    options = {
      page: params[:page],
      topic_ids: param_to_integer_list(:topic_ids),
      exclude_category: (params[:exclude_category] || select_menu_item.try(:filter)),
      category: params[:category],
      order: params[:order],
      ascending: params[:ascending],
      min_posts: params[:min_posts],
      max_posts: params[:max_posts],
      status: params[:status],
      search: params[:search]
    }
    options[:no_subcategories] = true if params[:no_subcategories] == 'true'

    options
  end

  def select_menu_item
    menu_item = SiteSetting.top_menu_items.select do |mu|
      (mu.has_specific_category? && mu.specific_category == @category.try(:slug)) ||
      action_name == mu.name ||
      (action_name.include?("top") && mu.name == "top")
    end.first

    menu_item = nil if menu_item.try(:has_specific_category?) && menu_item.specific_category == @category.try(:slug)
    menu_item
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

  def construct_next_url_with(opts, url_prefix = nil)
    method = url_prefix.blank? ? "#{action_name}_path" : "#{url_prefix}_#{action_name}_path"
    public_send(method, opts.merge(next_page_params(opts)))
  end

  def construct_prev_url_with(opts, url_prefix = nil)
    method = url_prefix.blank? ? "#{action_name}_path" : "#{url_prefix}_#{action_name}_path"
    public_send(method, opts.merge(prev_page_params(opts)))
  end

  def generate_top_lists(options)
    top = TopLists.new

    options[:per_page] = SiteSetting.topics_per_period_in_top_summary
    topic_query = TopicQuery.new(current_user, options)

    if current_user.present?
      periods = [ListController.best_period_for(current_user.previous_visit_at, options[:category])]
    else
      periods = TopTopic.periods
    end

    periods.each { |period| top.send("#{period}=", topic_query.list_top_for(period)) }

    top
  end

  def self.best_period_for(previous_visit_at, category_id=nil)
    best_periods_for(previous_visit_at).each do |period|
      top_topics = TopTopic.where("#{period}_score > 0")
      if category_id
        top_topics = top_topics.joins(:topic).where("topics.category_id = ?", category_id)
      end
      return period if top_topics.count >= SiteSetting.topics_per_period_in_top_page
    end
    # default period is yearly
    :yearly
  end

  def self.best_periods_for(date)
    date ||= 1.year.ago
    periods = []
    periods << :daily if date > 8.days.ago
    periods << :weekly if date > 35.days.ago
    periods << :monthly if date > 180.days.ago
    periods << :yearly
    periods
  end

end
