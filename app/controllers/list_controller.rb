# frozen_string_literal: true

class ListController < ApplicationController
  include TopicListResponder
  include TopicQueryParams

  skip_before_action :check_xhr

  before_action :set_category,
                only: [
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

  before_action :ensure_logged_in,
                except: [
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
                  :group_topics,
                  :filter,
                ].flatten

  rescue_from ActionController::Redirecting::UnsafeRedirectError do
    rescue_discourse_actions(:not_found, 404)
  end

  # Create our filters
  Discourse.filters.each do |filter|
    define_method(filter) do |options = nil|
      list_opts = build_topic_list_options
      list_opts.merge!(options) if options
      user = list_target_user
      if params[:category].blank? && filter == :latest &&
           !SiteSetting.show_category_definitions_in_topic_lists
        list_opts[:no_definitions] = true
      end

      list = TopicQuery.new(user, list_opts).public_send("list_#{filter}")

      if guardian.can_create_shared_draft? && @category.present?
        if @category.id == SiteSetting.shared_drafts_category.to_i
          # On shared drafts, show the destination category
          list.topics.each { |t| t.includes_destination_category = t.shared_draft.present? }
        else
          # When viewing a non-shared draft category, find topics whose
          # destination are this category
          shared_drafts =
            TopicQuery.new(
              user,
              category: SiteSetting.shared_drafts_category,
              destination_category_id: list_opts[:category],
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
        @rss_description = filter

        # Note the first is the default and we don't add a title
        if (filter.to_s != current_homepage) && use_crawler_layout?
          filter_title = I18n.t("js.filters.#{filter}.title", count: 0)

          if list_opts[:category] && @category
            @title =
              I18n.t("js.filters.with_category", filter: filter_title, category: @category.name)
          else
            @title = I18n.t("js.filters.with_topics", filter: filter_title)
          end

          @title << " - #{SiteSetting.title}"
        elsif @category.blank? && (filter.to_s == current_homepage) &&
              SiteSetting.short_site_description.present?
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

  def filter
    topic_query_opts = { no_definitions: !SiteSetting.show_category_definitions_in_topic_lists }

    %i[page q].each do |key|
      if params.key?(key.to_s)
        value = params[key]
        raise Discourse::InvalidParameters.new(key) if !TopicQuery.validate?(key, value)
        topic_query_opts[key] = value
      end
    end

    user = list_target_user
    list = TopicQuery.new(user, topic_query_opts).list_filter
    list.more_topics_url = construct_url_with(:next, topic_query_opts)
    list.prev_topics_url = construct_url_with(:prev, topic_query_opts)

    respond_with_list(list)
  end

  def category_default
    canonical_url "#{Discourse.base_url_no_prefix}#{@category.url}"
    view_method = @category.default_view
    view_method = "latest" if %w[latest top].exclude?(view_method)

    self.public_send(view_method, category: @category.id)
  end

  def topics_by
    list_opts = build_topic_list_options
    target_user =
      fetch_user_from_params(
        {
          include_inactive:
            current_user.try(:staff?) || (current_user && SiteSetting.show_inactive_accounts),
        },
        %i[user_stat user_option],
      )
    ensure_can_see_profile!(target_user)

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
    define_method action do
      message_route(action)
    end
  end

  def message_route(action)
    target_user =
      fetch_user_from_params(
        { include_inactive: current_user.try(:staff?) },
        %i[user_stat user_option],
      )

    case action
    when :private_messages_unread, :private_messages_new, :private_messages_group_new,
         :private_messages_group_unread
      raise Discourse::NotFound if target_user.id != current_user.id
    when :private_messages_tag
      raise Discourse::NotFound if !guardian.can_tag_pms?
    when :private_messages_warnings
      guardian.ensure_can_see_warnings!(target_user)
    when :private_messages_group, :private_messages_group_archive
      group = Group.find_by("LOWER(name) = ?", params[:group_name].downcase)
      raise Discourse::NotFound if !group
      raise Discourse::NotFound unless guardian.can_see_group_messages?(group)
    else
      guardian.ensure_can_see_private_messages!(target_user.id)
    end

    list_opts = build_topic_list_options
    list = generate_list_for(action.to_s, target_user, list_opts)
    url_prefix = "topics"
    list.more_topics_url = construct_url_with(:next, list_opts, url_prefix)
    list.prev_topics_url = construct_url_with(:prev, list_opts, url_prefix)
    respond_with_list(list)
  end

  %i[
    private_messages
    private_messages_sent
    private_messages_unread
    private_messages_new
    private_messages_archive
    private_messages_group
    private_messages_group_new
    private_messages_group_unread
    private_messages_group_archive
    private_messages_warnings
    private_messages_tag
  ].each { |action| generate_message_route(action) }

  def latest_feed
    discourse_expires_in 1.minute

    options = { order: "created" }.merge(build_topic_list_options)

    @title = "#{SiteSetting.title} - #{I18n.t("rss_description.latest")}"
    @link = "#{Discourse.base_url}/latest"
    @atom_link = "#{Discourse.base_url}/latest.rss"
    @description = I18n.t("rss_description.latest")
    @topic_list = TopicQuery.new(nil, options).list_latest

    render "list", formats: [:rss]
  end

  def top_feed
    discourse_expires_in 1.minute

    @title = "#{SiteSetting.title} - #{I18n.t("rss_description.top")}"
    @link = "#{Discourse.base_url}/top"
    @atom_link = "#{Discourse.base_url}/top.rss"
    @description = I18n.t("rss_description.top")
    period = params[:period] || SiteSetting.top_page_default_timeframe.to_sym
    TopTopic.validate_period(period)

    @topic_list = TopicQuery.new(nil).list_top_for(period)

    render "list", formats: [:rss]
  end

  def hot_feed
    discourse_expires_in 1.minute

    @topic_list = TopicQuery.new(nil).list_hot

    render "list", formats: [:rss]
  end

  def category_feed
    guardian.ensure_can_see!(@category)
    discourse_expires_in 1.minute

    @title = "#{@category.name} - #{SiteSetting.title}"
    @link = "#{Discourse.base_url_no_prefix}#{@category.url}"
    @atom_link = "#{Discourse.base_url_no_prefix}#{@category.url}.rss"
    @description =
      "#{I18n.t("topics_in_category", category: @category.name)} #{@category.description}"
    @topic_list = TopicQuery.new(current_user).list_new_in_category(@category)

    render "list", formats: [:rss]
  end

  def user_topics_feed
    discourse_expires_in 1.minute
    target_user = fetch_user_from_params
    ensure_can_see_profile!(target_user)

    @title =
      "#{SiteSetting.title} - #{I18n.t("rss_description.user_topics", username: target_user.username)}"
    @link = "#{target_user.full_url}/activity/topics"
    @atom_link = "#{target_user.full_url}/activity/topics.rss"
    @description = I18n.t("rss_description.user_topics", username: target_user.username)

    @topic_list = TopicQuery.new(nil, order: "created").public_send("list_topics_by", target_user)

    render "list", formats: [:rss]
  end

  def top(options = nil)
    options ||= {}
    period = params[:period]
    period ||=
      ListController.best_period_for(current_user.try(:previous_visit_at), options[:category])
    TopTopic.validate_period(period)
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
      @rss = "top"
      @params = { period: period }
      @rss_description = "top_#{period}"

      if use_crawler_layout?
        @title = I18n.t("js.filters.top.#{period}.title") + " - #{SiteSetting.title}"
      end

      respond_with_list(list)
    end

    define_method("category_top_#{period}") do
      self.public_send("top_#{period}", category: @category.id)
    end

    define_method("category_none_top_#{period}") do
      self.public_send("top_#{period}", category: @category.id, no_subcategories: true)
    end

    # rss feed
    define_method("top_#{period}_feed") do |options = nil|
      discourse_expires_in 1.minute

      @description = I18n.t("rss_description.top_#{period}")
      @title = "#{SiteSetting.title} - #{@description}"
      @link = "#{Discourse.base_url}/top?period=#{period}"
      @atom_link = "#{Discourse.base_url}/top.rss?period=#{period}"
      @topic_list = TopicQuery.new(nil).list_top_for(period)

      render "list", formats: [:rss]
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
    route_params = { format: "json" }

    if @category.present?
      slug_path = @category.slug_path

      route_params[:category_slug_path_with_id] = (slug_path + [@category.id.to_s]).join("/")
    end

    route_params[:username] = UrlHelper.encode_component(params[:username]) if params[
      :username
    ].present?
    route_params[:period] = params[:period] if params[:period].present?
    route_params
  end

  def set_category
    category_slug_path_with_id = params.require(:category_slug_path_with_id)

    @category = Category.find_by_slug_path_with_id(category_slug_path_with_id)
    raise Discourse::NotFound.new("category not found", check_permalinks: true) if @category.nil?

    params[:category] = @category.id.to_s

    if !guardian.can_see?(@category)
      if SiteSetting.detailed_404
        raise Discourse::InvalidAccess
      else
        raise Discourse::NotFound
      end
    end

    # Check if the category slug is incorrect and redirect to a link containing
    # the correct one.
    current_slug = category_slug_path_with_id
    if SiteSetting.slug_generation_method == "encoded"
      current_slug = current_slug.split("/").map { |slug| CGI.escape(slug) }.join("/")
    end
    real_slug = @category.full_slug("/")
    if CGI.unescape(current_slug) != CGI.unescape(real_slug)
      url = CGI.unescape(request.fullpath).gsub(current_slug, real_slug)
      if ActionController::Base.config.relative_url_root
        url = url.sub(ActionController::Base.config.relative_url_root, "")
      end

      return redirect_to path(url), status: 301
    end

    @description_meta =
      if @category.uncategorized?
        I18n.t("category.uncategorized_description", locale: SiteSetting.default_locale)
      elsif @category.description_text.present?
        @category.description_text
      else
        SiteSetting.site_description
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

    url = public_send(method, opts.merge(page_params)).sub(".json?", "?")

    # Unicode usernames need to be encoded when calling Rails' path helper. However, it means that the already
    # encoded username are encoded again which we do not want. As such, we unencode the url once when unicode usernames
    # have been enabled.
    url = UrlHelper.unencode(url) if SiteSetting.unicode_usernames

    url
  end

  def ensure_can_see_profile!(target_user = nil)
    raise Discourse::NotFound unless guardian.can_see_profile?(target_user)
  end

  def self.best_period_for(previous_visit_at, category_id = nil)
    default_period =
      (
        (category_id && Category.where(id: category_id).pick(:default_top_period)) ||
          SiteSetting.top_page_default_timeframe
      ).to_sym

    best_period_with_topics_for(previous_visit_at, category_id, default_period) || default_period
  end

  def self.best_period_with_topics_for(
    previous_visit_at,
    category_id = nil,
    default_period = SiteSetting.top_page_default_timeframe
  )
    best_periods_for(previous_visit_at, default_period.to_sym).find do |period|
      top_topics = TopTopic.where("#{period}_score > 0")
      top_topics =
        top_topics.joins(:topic).where("topics.category_id = ?", category_id) if category_id
      top_topics = top_topics.limit(SiteSetting.topics_per_period_in_top_page)
      top_topics.count == SiteSetting.topics_per_period_in_top_page
    end
  end

  def self.best_periods_for(date, default_period = :all)
    return [default_period, :all].uniq unless date

    periods = []
    periods << :daily if date > (1.week + 1.day).ago
    periods << :weekly if date > (1.month + 1.week).ago
    periods << :monthly if date > (3.months + 3.weeks).ago
    periods << :quarterly if date > (1.year + 1.month).ago
    periods << :yearly if date > 3.years.ago
    periods << :all
    periods
  end
end
