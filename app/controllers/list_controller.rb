# frozen_string_literal: true

class ListController < ApplicationController
  include TopicListResponder
  include TopicQueryParams

  skip_before_action :check_xhr

  before_action :set_category, only: [
    :category_default,
    # filtered topics lists
    Discourse.filters.map { |f| :"category_#{f}" },
    Discourse.filters.map { |f| :"category_none_#{f}" },
    # top summaries
    :category_top,
    :category_none_top,
    # top pages (ie. with a period)
    TopTopic.periods.map { |p| :"category_top_#{p}" },
    TopTopic.periods.map { |p| :"category_none_top_#{p}" },
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
    # category feeds
    :category_feed,
    # user topics feed
    :user_topics_feed,
    # top summaries
    :top,
    :category_top,
    :category_none_top,
    # top pages (ie. with a period)
    TopTopic.periods.map { |p| :"top_#{p}" },
    TopTopic.periods.map { |p| :"top_#{p}_feed" },
    TopTopic.periods.map { |p| :"category_top_#{p}" },
    TopTopic.periods.map { |p| :"category_none_top_#{p}" },
    :group_topics
  ].flatten

  # Create our filters
  Discourse.filters.each do |filter|
    define_method(filter) do |options = nil|
      list_opts = build_topic_list_options
      list_opts.merge!(options) if options
      user = list_target_user
      list_opts[:no_definitions] = true if params[:category].blank? && filter == :latest

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
        elsif @category.blank? && (filter.to_s == current_homepage) && SiteSetting.short_site_description.present?
          @title = "#{SiteSetting.title} - #{SiteSetting.short_site_description}"
        end
      end

      respond_with_list(list)
    end

    define_method("category_#{filter}") do
      canonical_url "#{Discourse.base_url_no_prefix}#{@category.url}"
      self.public_send(filter, category: @category.id)
    end

    define_method("category_none_#{filter}") do
      self.public_send(filter, category: @category.id, no_subcategories: true)
    end
  end

  def category_default
    canonical_url "#{Discourse.base_url_no_prefix}#{@category.url}"
    view_method = @category.default_view
    view_method = 'latest' unless %w(latest top).include?(view_method)

    self.public_send(view_method, category: @category.id)
  end

  def topics_by
    list_opts = build_topic_list_options
    target_user = fetch_user_from_params({ include_inactive: current_user.try(:staff?) || (current_user && SiteSetting.show_inactive_accounts) }, [:user_stat, :user_option])
    list = generate_list_for("topics_by", target_user, list_opts)
    list.more_topics_url = construct_url_with(:next, list_opts)
    list.prev_topics_url = construct_url_with(:prev, list_opts)
    respond_with_list(list)
  end

  def group_topics
    group = Group.find_by(name: params[:group_name])
    raise Discourse::NotFound unless group
    guardian.ensure_can_see_group!(group)
    guardian.ensure_can_see_group_members!(group)

    list_opts = build_topic_list_options
    list = generate_list_for("group_topics", group, list_opts)
    list.more_topics_url = construct_url_with(:next, list_opts)
    list.prev_topics_url = construct_url_with(:prev, list_opts)
    respond_with_list(list)
  end

  def self.generate_message_route(action)
    define_method("#{action}") do
      list_opts = build_topic_list_options
      target_user = fetch_user_from_params({ include_inactive: current_user.try(:staff?) }, [:user_stat, :user_option])
      guardian.ensure_can_see_private_messages!(target_user.id)
      list = generate_list_for(action.to_s, target_user, list_opts)
      url_prefix = "topics"
      list.more_topics_url = construct_url_with(:next, list_opts, url_prefix)
      list.prev_topics_url = construct_url_with(:prev, list_opts, url_prefix)
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

    @topic_list = TopicQuery
      .new(nil, order: 'created')
      .public_send("list_topics_by", target_user)

    render 'list', formats: [:rss]
  end

  def top(options = nil)
    options ||= {}
    period = ListController.best_period_for(current_user.try(:previous_visit_at), options[:category])
    public_send("top_#{period}", options)
  end

  def category_top
    top(category: @category.id)
  end

  def category_none_top
    top(category: @category.id, no_subcategories: true)
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
      @rss = "top_#{period}"

      if use_crawler_layout?
        @title = I18n.t("js.filters.top.#{period}.title") + " - #{SiteSetting.title}"
      end

      respond_with_list(list)
    end

    define_method("category_top_#{period}") do
      self.public_send("top_#{period}", category: @category.id)
    end

    define_method("category_none_top_#{period}") do
      self.public_send("top_#{period}",
        category: @category.id,
        no_subcategories: true
      )
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

  def next_page_params
    page_params.merge(page: params[:page].to_i + 1)
  end

  def prev_page_params
    pg = params[:page].to_i
    if pg > 1
      page_params.merge(page: pg - 1)
    else
      page_params.merge(page: nil)
    end
  end

  private

  def page_params
    route_params = { format: 'json' }

    if @category.present?
      slug_path = @category.slug_path

      route_params[:category_slug_path_with_id] =
        (slug_path + [@category.id.to_s]).join("/")
    end

    route_params[:username] = UrlHelper.encode_component(params[:username]) if params[:username].present?
    route_params
  end

  def set_category
    parts = params.require(:category_slug_path_with_id).split('/')

    if !parts.empty? && parts.last =~ /\A\d+\Z/
      id = parts.pop.to_i
    end
    slug_path = parts unless parts.empty?

    if id.present?
      @category = Category.find_by_id(id)
    elsif slug_path.present?
      if (1..2).include?(slug_path.size)
        @category = Category.find_by_slug(*slug_path.reverse)
      end

      # Legacy paths
      if @category.nil? && parts.last =~ /\A\d+-/
        @category = Category.find_by_id(parts.last.to_i)
      end
    end

    raise Discourse::NotFound.new("category not found", check_permalinks: true) if @category.nil?

    params[:category] = @category.id.to_s

    @description_meta = @category.description_text
    if !guardian.can_see?(@category)
      if SiteSetting.detailed_404
        raise Discourse::InvalidAccess
      else
        raise Discourse::NotFound
      end
    end

    if use_crawler_layout?
      @subcategories = @category.subcategories.select { |c| guardian.can_see?(c) }
    end
  end

  def list_target_user
    if params[:user_id] && guardian.is_staff?
      User.find(params[:user_id].to_i)
    else
      current_user
    end
  end

  def generate_list_for(action, target_user, opts)
    TopicQuery.new(current_user, opts).public_send("list_#{action}", target_user)
  end

  def construct_url_with(action, opts, url_prefix = nil)
    method = url_prefix.blank? ? "#{action_name}_path" : "#{url_prefix}_#{action_name}_path"

    page_params =
      case action
      when :prev
        prev_page_params
      when :next
        next_page_params
      else
        raise "unreachable"
      end

    opts = opts.dup
    if SiteSetting.unicode_usernames && opts[:group_name]
      opts[:group_name] = UrlHelper.encode_component(opts[:group_name])
    end
    opts.delete(:category) if page_params.include?(:category_slug_path_with_id)

    public_send(method, opts.merge(page_params)).sub('.json?', '?')
  end

  def self.best_period_for(previous_visit_at, category_id = nil)
    default_period = ((category_id && Category.where(id: category_id).pluck_first(:default_top_period)) ||
          SiteSetting.top_page_default_timeframe).to_sym

    best_period_with_topics_for(previous_visit_at, category_id, default_period) || default_period
  end

  def self.best_period_with_topics_for(previous_visit_at, category_id = nil, default_period = SiteSetting.top_page_default_timeframe)
    best_periods_for(previous_visit_at, default_period.to_sym).find do |period|
      top_topics = TopTopic.where("#{period}_score > 0")
      top_topics = top_topics.joins(:topic).where("topics.category_id = ?", category_id) if category_id
      top_topics = top_topics.limit(SiteSetting.topics_per_period_in_top_page)
      top_topics.count == SiteSetting.topics_per_period_in_top_page
    end
  end

  def self.best_periods_for(date, default_period = :all)
    return [default_period, :all].uniq unless date

    periods = []
    periods << :daily     if date > (1.week + 1.day).ago
    periods << :weekly    if date > (1.month + 1.week).ago
    periods << :monthly   if date > (3.months + 3.weeks).ago
    periods << :quarterly if date > (1.year + 1.month).ago
    periods << :yearly    if date > 3.years.ago
    periods << :all
    periods
  end

end
