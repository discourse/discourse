class ListController < ApplicationController

  before_filter :ensure_logged_in, except: [:latest, :hot, :category, :category_feed, :latest_feed, :hot_feed, :topics_by]
  before_filter :set_category, only: [:category, :category_feed]
  skip_before_filter :check_xhr

  # Create our filters
  [:latest, :hot, :favorited, :read, :posted, :unread, :new].each do |filter|
    define_method(filter) do
      list_opts = build_topic_list_options
      user = list_target_user
      list = TopicQuery.new(user, list_opts).public_send("list_#{filter}")
      list.more_topics_url = url_for(self.public_send "#{filter}_path".to_sym, list_opts.merge(format: 'json', page: next_page))

      respond(list)
    end
  end

  [:latest, :hot].each do |filter|
    define_method("#{filter}_feed") do
      anonymous_etag(@category) do
        @title = "#{filter.capitalize} Topics"
        @link = "#{Discourse.base_url}/#{filter}"
        @description = I18n.t("rss_description.#{filter}")
        @atom_link = "#{Discourse.base_url}/#{filter}.rss"
        @topic_list = TopicQuery.new(current_user).public_send("list_#{filter}")
        render 'list', formats: [:rss]
      end
    end
  end

  def topics_by
    list_opts = build_topic_list_options
    list = TopicQuery.new(current_user, list_opts).list_topics_by(fetch_user_from_params)
    list.more_topics_url = url_for(topics_by_path(list_opts.merge(format: 'json', page: next_page)))

    respond(list)
  end

  def private_messages
    list_opts = build_topic_list_options
    list = TopicQuery.new(current_user, list_opts).list_private_messages(fetch_user_from_params)
    list.more_topics_url = url_for(topics_private_messages_path(list_opts.merge(format: 'json', page: next_page)))

    respond(list)
  end

  def private_messages_sent
    list_opts = build_topic_list_options
    list = TopicQuery.new(current_user, list_opts).list_private_messages_sent(fetch_user_from_params)
    list.more_topics_url = url_for(topics_private_messages_sent_path(list_opts.merge(format: 'json', page: next_page)))

    respond(list)
  end

  def private_messages_unread
    list_opts = build_topic_list_options
    list = TopicQuery.new(current_user, list_opts).list_private_messages_unread(fetch_user_from_params)
    list.more_topics_url = url_for(topics_private_messages_unread_path(list_opts.merge(format: 'json', page: next_page)))

    respond(list)
  end

  def category
    query = TopicQuery.new(current_user, page: params[:page])

    # If they choose uncategorized, return topics NOT in a category
    if request_is_for_uncategorized?
      list = query.list_uncategorized
    else
      if !@category
        raise Discourse::NotFound
        return
      end
      guardian.ensure_can_see!(@category)
      list = query.list_category(@category)
    end

    list.more_topics_url = url_for(category_list_path(params[:category], page: next_page, format: "json"))
    respond(list)
  end

  def category_feed
    raise Discourse::InvalidParameters.new('Category RSS of "uncategorized"') if request_is_for_uncategorized?

    guardian.ensure_can_see!(@category)

    anonymous_etag(@category) do
      @title = @category.name
      @link = "#{Discourse.base_url}/category/#{@category.slug}"
      @description = "#{I18n.t('topics_in_category', category: @category.name)} #{@category.description}"
      @atom_link = "#{Discourse.base_url}/category/#{@category.slug}.rss"
      @topic_list = TopicQuery.new.list_new_in_category(@category)
      render 'list', formats: [:rss]
    end
  end

  def popular_redirect
    # We've renamed popular to latest. Use a redirect until we're sure we can
    # safely remove this.
    redirect_to latest_path, :status => 301
  end

  protected

  def respond(list)

    list.draft_key = Draft::NEW_TOPIC
    list.draft_sequence = DraftSequence.current(current_user, Draft::NEW_TOPIC)

    draft = Draft.get(current_user, list.draft_key, list.draft_sequence) if current_user
    list.draft = draft

    discourse_expires_in 1.minute

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

  def next_page
    params[:page].to_i + 1
  end

  private

  def set_category
    slug = params.fetch(:category)
    @category = Category.where("slug = ?", slug).includes(:featured_users).first || Category.where("id = ?", slug.to_i).includes(:featured_users).first
  end

  def request_is_for_uncategorized?
    params[:category] == Slug.for(SiteSetting.uncategorized_name) ||
      params[:category] == SiteSetting.uncategorized_name ||
      params[:category] == 'uncategorized'
  end

  def build_topic_list_options
    # html format means we need to parse exclude category (aka filter) from the site options top menu
    menu_items = SiteSetting.top_menu_items
    menu_item = menu_items.select { |item| item.query_should_exclude_category?(action_name, params[:format]) }.first

    # exclude_category = 1. from params / 2. parsed from top menu / 3. nil
    return {
      page: params[:page],
      topic_ids: param_to_integer_list(:topic_ids),
      exclude_category: (params[:exclude_category] || menu_item.try(:filter))
    }
  end

  def list_target_user
    if params[:user_id] && guardian.is_staff?
      User.find(params[:user_id].to_i)
    else
      current_user
    end
  end
end
