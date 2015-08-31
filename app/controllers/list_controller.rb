require_dependency 'topic_list_responder'

class ListController < ApplicationController
  include TopicListResponder

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
  Discourse.filters.each_with_index do |filter, idx|
    define_method(filter) do |options = nil|
      list_opts = build_topic_list_options
      list_opts.merge!(options) if options
      user = list_target_user

      if filter == :latest && params[:category].blank?
        list_opts[:no_definitions] = true
      end

      list = TopicQuery.new(user, list_opts).public_send("list_#{filter}")
      list.more_topics_url = construct_url_with(:next, list_opts)
      list.prev_topics_url = construct_url_with(:prev, list_opts)
      if Discourse.anonymous_filters.include?(filter)
        @description = SiteSetting.site_description
        @rss = filter

        # Note the first is the default and we don't add a title
        if (filter.to_s != current_homepage) && use_crawler_layout?
          filter_title = I18n.t("js.filters.#{filter.to_s}.title", count: 0)
          if list_opts[:category]
            @title = I18n.t('js.filters.with_category', filter: filter_title, category: Category.find(list_opts[:category]).name)
          else
            @title = I18n.t('js.filters.with_topics', filter: filter_title)
          end
        end
      end

      respond_with_list(list)
    end

    define_method("category_#{filter}") do
      canonical_url "#{Discourse.base_url}#{@category.url}"
      self.send(filter, { category: @category.id })
    end

    define_method("category_none_#{filter}") do
      self.send(filter, { category: @category.id, no_subcategories: true })
    end

    define_method("parent_category_category_#{filter}") do
      canonical_url "#{Discourse.base_url}#{@category.url}"
      self.send(filter, { category: @category.id })
    end

    define_method("parent_category_category_none_#{filter}") do
      self.send(filter, { category: @category.id })
    end
  end

  Discourse.feed_filters.each do |filter|
    define_method("#{filter}_feed") do
      discourse_expires_in 1.minute

      @title = "#{SiteSetting.title} - #{I18n.t("rss_description.#{filter}")}"
      @link = "#{Discourse.base_url}/#{filter}"
      @description = I18n.t("rss_description.#{filter}")
      @atom_link = "#{Discourse.base_url}/#{filter}.rss"
      @topic_list = TopicQuery.new(nil, order: 'created').public_send("list_#{filter}")

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
      list.more_topics_url = url_for(construct_url_with(:next, list_opts, url_prefix))
      list.prev_topics_url = url_for(construct_url_with(:prev, list_opts, url_prefix))
      respond_with_list(list)
    end
  end

  def category_feed
    guardian.ensure_can_see!(@category)
    discourse_expires_in 1.minute

    @title = @category.name
    @link = "#{Discourse.base_url}#{@category.url}"
    @description = "#{I18n.t('topics_in_category', category: @category.name)} #{@category.description}"
    @atom_link = "#{Discourse.base_url}#{@category.url}.rss"
    @topic_list = TopicQuery.new.list_new_in_category(@category)

    render 'list', formats: [:rss]
  end

  def top(options=nil)
    options ||= {}
    period = ListController.best_period_for(current_user.try(:previous_visit_at), options[:category])
    send("top_#{period}", options)
  end

  def category_top
    top({ category: @category.id })
  end

  def category_none_top
    top({ category: @category.id, no_subcategories: true })
  end

  def parent_category_category_top
    top({ category: @category.id })
  end

  TopTopic.periods.each do |period|
    define_method("top_#{period}") do |options = nil|
      top_options = build_topic_list_options
      top_options.merge!(options) if options
      top_options[:per_page] = SiteSetting.topics_per_period_in_top_page
      user = list_target_user
      list = TopicQuery.new(user, top_options).list_top_for(period)
      list.for_period = period
      list.more_topics_url = construct_url_with(:next, top_options)
      list.prev_topics_url = construct_url_with(:prev, top_options)

      if use_crawler_layout?
        @title = I18n.t("js.filters.top.#{period}.title")
      end

      respond_with_list(list)
    end

    define_method("category_top_#{period}") do
      self.send("top_#{period}", { category: @category.id })
    end

    define_method("category_none_top_#{period}") do
      self.send("top_#{period}", { category: @category.id, no_subcategories: true })
    end

    define_method("parent_category_category_top_#{period}") do
      self.send("top_#{period}", { category: @category.id })
    end
  end

  protected

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
      raise Discourse::NotFound if parent_category_id.blank?
    end

    @category = Category.query_category(slug_or_id, parent_category_id)
    raise Discourse::NotFound if !@category

    @description_meta = @category.description_text
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
      filter: params[:filter],
      state: params[:state],
      search: params[:search],
      q: params[:q]
    }
    options[:no_subcategories] = true if params[:no_subcategories] == 'true'
    options[:slow_platform] = true if slow_platform?

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

  def construct_url_with(action, opts, url_prefix = nil)
    method = url_prefix.blank? ? "#{action_name}_path" : "#{url_prefix}_#{action_name}_path"
    url = if action == :prev
      public_send(method, opts.merge(prev_page_params(opts)))
    else # :next
      public_send(method, opts.merge(next_page_params(opts)))
    end
    url.sub('.json?','?')
  end

  def generate_top_lists(options)
    top = TopLists.new

    options[:per_page] = SiteSetting.topics_per_period_in_top_summary
    topic_query = TopicQuery.new(current_user, options)

    periods = [ListController.best_period_for(current_user.try(:previous_visit_at), options[:category])]

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
