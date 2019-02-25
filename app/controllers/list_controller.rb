require_dependency 'topic_list_responder'

class ListController < ApplicationController
  include TopicListResponder

  skip_before_action :check_xhr

  before_action :set_category, only: [
    :category_default,
    # filtered topics lists
    Discourse.filters.map { |f| :"category_#{f}" },
    Discourse.filters.map { |f| :"category_none_#{f}" },
    Discourse.filters.map { |f| :"parent_category_category_#{f}" },
    Discourse.filters.map { |f| :"parent_category_category_none_#{f}" },
    # top summaries
    :category_top,
    :category_none_top,
    :parent_category_category_top,
    # top pages (ie. with a period)
    TopTopic.periods.map { |p| :"category_top_#{p}" },
    TopTopic.periods.map { |p| :"category_none_top_#{p}" },
    TopTopic.periods.map { |p| :"parent_category_category_top_#{p}" },
    # category feeds
    :category_feed,
  ].flatten

  before_action :ensure_logged_in, except: [
    :topics_by,
    # anonymous filters
    Discourse.anonymous_filters,
    Discourse.anonymous_filters.map { |f| "#{f}_feed" },
    # anonymous categorized filters
    :category_default,
    Discourse.anonymous_filters.map { |f| :"category_#{f}" },
    Discourse.anonymous_filters.map { |f| :"category_none_#{f}" },
    Discourse.anonymous_filters.map { |f| :"parent_category_category_#{f}" },
    Discourse.anonymous_filters.map { |f| :"parent_category_category_none_#{f}" },
    # category feeds
    :category_feed,
    # user topics feed
    :user_topics_feed,
    # top summaries
    :top,
    :category_top,
    :category_none_top,
    :parent_category_category_top,
    # top pages (ie. with a period)
    TopTopic.periods.map { |p| :"top_#{p}" },
    TopTopic.periods.map { |p| :"top_#{p}_feed" },
    TopTopic.periods.map { |p| :"category_top_#{p}" },
    TopTopic.periods.map { |p| :"category_none_top_#{p}" },
    TopTopic.periods.map { |p| :"parent_category_category_top_#{p}" },
    :group_topics
  ].flatten

  # Create our filters
  Discourse.filters.each do |filter|
    define_method(filter) do |options = nil|
      list_opts = build_topic_list_options
      list_opts.merge!(options) if options
      user = list_target_user

      if params[:category].blank?
        if filter == :latest
          list_opts[:no_definitions] = true
        end
        if [:latest, :categories].include?(filter) && list_opts[:exclude_category_ids].blank?
          list_opts[:exclude_category_ids] = get_excluded_category_ids(list_opts[:category])
        end
      end

      list = TopicQuery.new(user, list_opts).public_send("list_#{filter}")

      if guardian.can_create_shared_draft? && @category.present?
        if @category.id == SiteSetting.shared_drafts_category.to_i
          # On shared drafts, show the destination category
          list.topics.each do |t|
            t.includes_destination_category = true
          end
        else
          # When viewing a non-shared draft category, find topics whose
          # destination are this category
          shared_drafts = TopicQuery.new(
            user,
            category: SiteSetting.shared_drafts_category,
            destination_category_id: list_opts[:category]
          ).list_latest

          if shared_drafts.present? && shared_drafts.topics.present?
            list.shared_drafts = shared_drafts.topics
          end
        end
      end

      list.more_topics_url = construct_url_with(:next, list_opts)
      list.prev_topics_url = construct_url_with(:prev, list_opts)
      if Discourse.anonymous_filters.include?(filter)
        @description = SiteSetting.site_description
        @rss = filter

        # Note the first is the default and we don't add a title
        if (filter.to_s != current_homepage) && use_crawler_layout?
          filter_title = I18n.t("js.filters.#{filter.to_s}.title", count: 0)
          if list_opts[:category] && @category
            @title = I18n.t('js.filters.with_category', filter: filter_title, category: @category.name)
          else
            @title = I18n.t('js.filters.with_topics', filter: filter_title)
          end
          @title << " - #{SiteSetting.title}"
        elsif (filter.to_s == current_homepage) && SiteSetting.short_site_description.present?
          @title = "#{SiteSetting.title} - #{SiteSetting.short_site_description}"
        end
      end

      respond_with_list(list)
    end

    define_method("category_#{filter}") do
      canonical_url "#{Discourse.base_url_no_prefix}#{@category.url}"
      self.send(filter, category: @category.id)
    end

    define_method("category_none_#{filter}") do
      self.send(filter, category: @category.id, no_subcategories: true)
    end

    define_method("parent_category_category_#{filter}") do
      canonical_url "#{Discourse.base_url_no_prefix}#{@category.url}"
      self.send(filter, category: @category.id)
    end

    define_method("parent_category_category_none_#{filter}") do
      self.send(filter, category: @category.id)
    end
  end

  def category_default
    canonical_url "#{Discourse.base_url_no_prefix}#{@category.url}"
    view_method = @category.default_view
    view_method = 'latest' unless %w(latest top).include?(view_method)

    if view_method == 'top'
      top(category: @category.id)
    else
      self.send(view_method)
    end
  end

  def topics_by
    list_opts = build_topic_list_options
    target_user = fetch_user_from_params({ include_inactive: current_user.try(:staff?) || (current_user && SiteSetting.show_inactive_accounts) }, [:user_stat, :user_option])
    list = generate_list_for("topics_by", target_user, list_opts)
    list.more_topics_url = url_for(construct_url_with(:next, list_opts))
    list.prev_topics_url = url_for(construct_url_with(:prev, list_opts))
    respond_with_list(list)
  end

  def group_topics
    group = Group.find_by(name: params[:group_name])
    raise Discourse::NotFound unless group
    guardian.ensure_can_see_group!(group)

    list_opts = build_topic_list_options
    list = generate_list_for("group_topics", group, list_opts)
    list.more_topics_url = url_for(construct_url_with(:next, list_opts))
    list.prev_topics_url = url_for(construct_url_with(:prev, list_opts))
    respond_with_list(list)
  end

  def self.generate_message_route(action)
    define_method("#{action}") do
      list_opts = build_topic_list_options
      target_user = fetch_user_from_params({ include_inactive: current_user.try(:staff?) }, [:user_stat, :user_option])
      guardian.ensure_can_see_private_messages!(target_user.id)
      list = generate_list_for(action.to_s, target_user, list_opts)
      url_prefix = "topics"
      list.more_topics_url = url_for(construct_url_with(:next, list_opts, url_prefix))
      list.prev_topics_url = url_for(construct_url_with(:prev, list_opts, url_prefix))
      respond_with_list(list)
    end
  end

  %i{
    private_messages
    private_messages_sent
    private_messages_unread
    private_messages_archive
    private_messages_group
    private_messages_group_archive
    private_messages_tag
  }.each do |action|
    generate_message_route(action)
  end

  def latest_feed
    discourse_expires_in 1.minute

    @title = "#{SiteSetting.title} - #{I18n.t("rss_description.latest")}"
    @link = "#{Discourse.base_url}/latest"
    @atom_link = "#{Discourse.base_url}/latest.rss"
    @description = I18n.t("rss_description.latest")
    @topic_list = TopicQuery.new(nil, order: 'created').list_latest

    render 'list', formats: [:rss]
  end

  def top_feed
    discourse_expires_in 1.minute

    @title = "#{SiteSetting.title} - #{I18n.t("rss_description.top")}"
    @link = "#{Discourse.base_url}/top"
    @atom_link = "#{Discourse.base_url}/top.rss"
    @description = I18n.t("rss_description.top")
    @topic_list = TopicQuery.new(nil).list_top_for(SiteSetting.top_page_default_timeframe.to_sym)

    render 'list', formats: [:rss]
  end

  def category_feed
    guardian.ensure_can_see!(@category)
    discourse_expires_in 1.minute

    @title = "#{@category.name} - #{SiteSetting.title}"
    @link = "#{Discourse.base_url_no_prefix}#{@category.url}"
    @atom_link = "#{Discourse.base_url_no_prefix}#{@category.url}.rss"
    @description = "#{I18n.t('topics_in_category', category: @category.name)} #{@category.description}"
    @topic_list = TopicQuery.new(current_user).list_new_in_category(@category)

    render 'list', formats: [:rss]
  end

  def user_topics_feed
    discourse_expires_in 1.minute
    target_user = fetch_user_from_params

    @title = "#{SiteSetting.title} - #{I18n.t("rss_description.user_topics", username: target_user.username)}"
    @link = "#{Discourse.base_url}/u/#{target_user.username}/activity/topics"
    @atom_link = "#{Discourse.base_url}/u/#{target_user.username}/activity/topics.rss"
    @description = I18n.t("rss_description.user_topics", username: target_user.username)
    @topic_list = TopicQuery.new(nil, order: 'created').send("list_topics_by", target_user)

    render 'list', formats: [:rss]
  end

  def top(options = nil)
    options ||= {}
    period = ListController.best_period_for(current_user.try(:previous_visit_at), options[:category])
    send("top_#{period}", options)
  end

  def category_top
    top(category: @category.id)
  end

  def category_none_top
    top(category: @category.id, no_subcategories: true)
  end

  def parent_category_category_top
    top(category: @category.id)
  end

  TopTopic.periods.each do |period|
    define_method("top_#{period}") do |options = nil|
      top_options = build_topic_list_options
      top_options.merge!(options) if options
      top_options[:per_page] = SiteSetting.topics_per_period_in_top_page

      if "top".freeze == current_homepage && top_options[:exclude_category_ids].blank?
        top_options[:exclude_category_ids] = get_excluded_category_ids(top_options[:category])
      end

      user = list_target_user
      list = TopicQuery.new(user, top_options).list_top_for(period)
      list.for_period = period
      list.more_topics_url = construct_url_with(:next, top_options)
      list.prev_topics_url = construct_url_with(:prev, top_options)
      @rss = "top_#{period}"

      if use_crawler_layout?
        @title = I18n.t("js.filters.top.#{period}.title") + " - #{SiteSetting.title}"
      end

      respond_with_list(list)
    end

    define_method("category_top_#{period}") do
      self.send("top_#{period}", category: @category.id)
    end

    define_method("category_none_top_#{period}") do
      self.send("top_#{period}", category: @category.id, no_subcategories: true)
    end

    define_method("parent_category_category_top_#{period}") do
      self.send("top_#{period}", category: @category.id)
    end

    # rss feed
    define_method("top_#{period}_feed") do |options = nil|
      discourse_expires_in 1.minute

      @description = I18n.t("rss_description.top_#{period}")
      @title = "#{SiteSetting.title} - #{@description}"
      @link = "#{Discourse.base_url}/top/#{period}"
      @atom_link = "#{Discourse.base_url}/top/#{period}.rss"
      @topic_list = TopicQuery.new(nil).list_top_for(period)

      render 'list', formats: [:rss]
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
    route_params = { format: 'json' }
    route_params[:category]        = @category.slug_for_url                  if @category
    route_params[:parent_category] = @category.parent_category.slug_for_url  if @category && @category.parent_category
    route_params[:order]           = opts[:order]                            if opts[:order].present?
    route_params[:ascending]       = opts[:ascending]                        if opts[:ascending].present?
    route_params[:username]        = UrlHelper.escape_uri(params[:username]) if params[:username].present?
    route_params
  end

  def set_category
    slug_or_id = params.fetch(:category)
    parent_slug_or_id = params[:parent_category]
    id = params[:id].to_i

    parent_category_id = nil
    if parent_slug_or_id.present?
      parent_category_id = Category.query_parent_category(parent_slug_or_id)
      raise Discourse::NotFound.new("category not found", check_permalinks: true) if parent_category_id.blank? && !id
    end

    @category = Category.query_category(slug_or_id, parent_category_id)

    # Redirect if we have `/c/:parent_category/:category/:id`
    if id
      category = Category.find_by_id(id)
      (redirect_to category.url, status: 301) && return if category
    end

    raise Discourse::NotFound.new("category not found", check_permalinks: true) if !@category

    @description_meta = @category.description_text
    raise Discourse::NotFound unless guardian.can_see?(@category)

    if use_crawler_layout?
      @subcategories = @category.subcategories.select { |c| guardian.can_see?(c) }
    end
  end

  def build_topic_list_options
    options = {}
    params[:tags] = [params[:tag_id].parameterize] if params[:tag_id].present? && guardian.can_tag_pms?

    TopicQuery.public_valid_options.each do |key|
      if params.key?(key)
        val = options[key] = params[key]
        if !TopicQuery.validate?(key, val)
          raise Discourse::InvalidParameters.new key
        end
      end
    end

    # hacky columns get special handling
    options[:topic_ids] = param_to_integer_list(:topic_ids)
    options[:no_subcategories] = options[:no_subcategories] == 'true'

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

  def construct_url_with(action, opts, url_prefix = nil)
    method = url_prefix.blank? ? "#{action_name}_path" : "#{url_prefix}_#{action_name}_path"
    url = if action == :prev
      public_send(method, opts.merge(prev_page_params(opts)))
    else # :next
      public_send(method, opts.merge(next_page_params(opts)))
    end
    url.sub('.json?', '?')
  end

  def get_excluded_category_ids(current_category = nil)
    exclude_category_ids = Category.where(suppress_from_latest: true)
    exclude_category_ids = exclude_category_ids.where.not(id: current_category) if current_category
    exclude_category_ids.pluck(:id)
  end

  def self.best_period_for(previous_visit_at, category_id = nil)
    default_period = ((category_id && Category.where(id: category_id).pluck(:default_top_period).first) ||
          SiteSetting.top_page_default_timeframe).to_sym

    best_period_with_topics_for(previous_visit_at, category_id, default_period) || default_period
  end

  def self.best_period_with_topics_for(previous_visit_at, category_id = nil, default_period = SiteSetting.top_page_default_timeframe)
    best_periods_for(previous_visit_at, default_period.to_sym).each do |period|
      top_topics = TopTopic.where("#{period}_score > 0")
      top_topics = top_topics.joins(:topic).where("topics.category_id = ?", category_id) if category_id
      top_topics = top_topics.limit(SiteSetting.topics_per_period_in_top_page)
      return period if top_topics.count == SiteSetting.topics_per_period_in_top_page
    end

    false
  end

  def self.best_periods_for(date, default_period = :all)
    date ||= 1.year.ago
    periods = []
    periods << default_period if :all     != default_period
    periods << :daily         if :daily   != default_period && date > 8.days.ago
    periods << :weekly        if :weekly  != default_period && date > 35.days.ago
    periods << :monthly       if :monthly != default_period && date > 180.days.ago
    periods << :yearly        if :yearly  != default_period
    periods
  end

end
