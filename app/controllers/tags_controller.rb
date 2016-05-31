require_dependency 'topic_list_responder'
require_dependency 'topics_bulk_action'
require_dependency 'topic_query'

class TagsController < ::ApplicationController
  include TopicListResponder

  before_filter :ensure_tags_enabled

  skip_before_filter :check_xhr, only: [:tag_feed, :show, :index]
  before_filter :ensure_logged_in, only: [:notifications, :update_notifications, :update]
  before_filter :set_category_from_params, except: [:index, :update, :destroy, :tag_feed, :search, :notifications, :update_notifications]

  def index
    categories = Category.where("id in (select category_id from category_tags)")
                         .where("id in (?)", guardian.allowed_category_ids)
                         .preload(:tags)
    category_tag_counts = categories.map { |c| {id: c.id, tags: self.class.tag_counts_json(Tag.category_tags_by_count_query(c, limit: 300).count)} }

    tag_counts = self.class.tags_by_count(guardian, limit: 300).count
    @tags = self.class.tag_counts_json(tag_counts)

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
      @tag_id = DiscourseTagging.clean_tag(params[:tag_id])

      page = params[:page].to_i

      query = TopicQuery.new(current_user, build_topic_list_options)

      results = query.send("#{filter}_results")

      if @filter_on_category
        category_ids = [@filter_on_category.id] + @filter_on_category.subcategories.pluck(:id)
        results = results.where(category_id: category_ids)
      end

      @list = query.create_list(:by_tag, {}, results)

      @list.draft_key = Draft::NEW_TOPIC
      @list.draft_sequence = DraftSequence.current(current_user, Draft::NEW_TOPIC)
      @list.draft = Draft.get(current_user, @list.draft_key, @list.draft_sequence) if current_user

      @list.more_topics_url = list_by_tag_path(tag_id: @tag_id, page: page + 1)
      @rss = "tag"

      if @list.topics.size == 0 && !Tag.where(name: @tag_id).exists?
        raise Discourse::NotFound
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
      render json: { tag: { id: new_tag_name }}
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

    tag_id = DiscourseTagging.clean_tag(params[:tag_id])
    @link = "#{Discourse.base_url}/tags/#{tag_id}"
    @description = I18n.t("rss_by_tag", tag: tag_id)
    @title = "#{SiteSetting.title} - #{@description}"
    @atom_link = "#{Discourse.base_url}/tags/#{tag_id}.rss"

    query = TopicQuery.new(current_user, {tags: [tag_id]})
    latest_results = query.latest_results
    @topic_list = query.create_list(:by_tag, {}, latest_results)

    render 'list/list', formats: [:rss]
  end

  def search
    category = params[:categoryId] ? Category.find_by_id(params[:categoryId]) : nil

    tags_with_counts = DiscourseTagging.filter_allowed_tags(
      self.class.tags_by_count(guardian, params.slice(:limit)),
      guardian,
      { for_input: params[:filterForInput], term: params[:q], category: category }
    )

    tags = tags_with_counts.count.map {|t, c| { id: t, text: t, count: c } }

    unused_tags = DiscourseTagging.filter_allowed_tags(
      Tag.where(topic_count: 0),
      guardian,
      { for_input: params[:filterForInput], term: params[:q], category: category }
    )

    unused_tags.each do |t|
      tags << { id: t.name, text: t.name, count: 0 }
    end

    render json: { results: tags }
  end

  def notifications
    tag = Tag.find_by_name(params[:tag_id])
    raise Discourse::NotFound unless tag
    level = tag.tag_users.where(user: current_user).first.try(:notification_level) || TagUser.notification_levels[:regular]
    render json: { tag_notification: { id: params[:tag_id], notification_level: level.to_i } }
  end

  def update_notifications
    tag = Tag.find_by_name(params[:tag_id])
    raise Discourse::NotFound unless tag
    level = params[:tag_notification][:notification_level].to_i
    TagUser.change(current_user.id, tag.id, level)
    render json: {notification_level: level}
  end

  def check_hashtag
    tag_values = params[:tag_values].each(&:downcase!)

    valid_tags = TopicCustomField.where(name: DiscourseTagging::TAGS_FIELD_NAME, value: tag_values).map do |tag|
      { value: tag.value, url: "#{Discourse.base_url}/tags/#{tag.value}" }
    end.compact

    render json: { valid: valid_tags }
  end

  private

    def ensure_tags_enabled
      raise Discourse::NotFound unless SiteSetting.tagging_enabled?
    end

    def self.tags_by_count(guardian, opts={})
      guardian.filter_allowed_categories(Tag.tags_by_count_query(opts))
    end

    def self.tag_counts_json(tag_counts)
      tag_counts.map {|t, c| { id: t, text: t, count: c } }
    end

    def set_category_from_params
      slug_or_id = params[:category]
      return true if slug_or_id.nil?

      parent_slug_or_id = params[:parent_category]

      parent_category_id = nil
      if parent_slug_or_id.present?
        parent_category_id = Category.query_parent_category(parent_slug_or_id)
        redirect_or_not_found and return if parent_category_id.blank?
      end

      @filter_on_category = Category.query_category(slug_or_id, parent_category_id)
      redirect_or_not_found and return if !@filter_on_category

      guardian.ensure_can_see!(@filter_on_category)
    end

    def build_topic_list_options
      options = {
        page: params[:page],
        topic_ids: param_to_integer_list(:topic_ids),
        exclude_category_ids: params[:exclude_category_ids],
        category: params[:category],
        tags: [params[:tag_id]],
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

    def redirect_or_not_found
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
end
