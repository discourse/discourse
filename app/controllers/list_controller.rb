class ListController < ApplicationController

  before_filter :ensure_logged_in, except: [:latest, :hot, :category, :category_feed]
  skip_before_filter :check_xhr

  # Create our filters
  [:latest, :hot, :favorited, :read, :posted, :unread, :new].each do |filter|
    define_method(filter) do
      list_opts = {page: params[:page]}

      # html format means we need to farm exclude from the site options
      if params[:format].blank? || params[:format] == "html"
        #TODO objectify this stuff
        SiteSetting.top_menu.split('|').each do |f|
          s = f.split(",")
          if s[0] == action_name || (action_name == "index" && s[0] == SiteSetting.homepage)
            list_opts[:exclude_category] = s[1][1..-1] if s.length == 2
          end
        end
      end
      list_opts[:exclude_category] = params[:exclude_category] if params[:exclude_category].present?

      list = TopicQuery.new(current_user, list_opts).send("list_#{filter}")
      list.more_topics_url = url_for(self.send "#{filter}_path".to_sym, list_opts.merge(format: 'json', page: next_page))

      respond(list)
    end
  end

  def category
    query = TopicQuery.new(current_user, page: params[:page])
    list = nil

    # If they choose uncategorized, return topics NOT in a category
    if params[:category] == Slug.for(SiteSetting.uncategorized_name) or params[:category] == SiteSetting.uncategorized_name or params[:category] == 'null-category'
      list = query.list_uncategorized
    else
      @category = Category.where("slug = ? or id = ?", params[:category], params[:category].to_i).includes(:featured_users).first
      guardian.ensure_can_see!(@category)
      list = query.list_category(@category)
    end

    list.more_topics_url = url_for(category_path(params[:category], page: next_page, format: "json"))
    respond(list)
  end

  def category_feed
    raise Discourse::InvalidParameters.new('Category RSS of "uncategorized"') if params[:category] == Slug.for(SiteSetting.uncategorized_name) || params[:category] == SiteSetting.uncategorized_name

    @category = Category.where("slug = ?", params[:category]).includes(:featured_users).first

    guardian.ensure_can_see!(@category)

    anonymous_etag(@category) do
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

end
