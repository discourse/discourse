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
    tag_counts = self.class.tags_by_count(guardian, limit: 300).count
    @tags = tag_counts.map {|t, c| { id: t, text: t, count: c } }

    respond_to do |format|
      format.html do
        render :index
      end
      format.json do
        render json: { tags: @tags }
      end
    end
  end

  Discourse.filters.each do |filter|
    define_method("show_#{filter}") do
      @tag_id = DiscourseTagging.clean_tag(params[:tag_id])

      # TODO PERF: doesn't scale:
      topics_tagged = TopicCustomField.where(name: DiscourseTagging::TAGS_FIELD_NAME, value: @tag_id).pluck(:topic_id)

      page = params[:page].to_i

      query = TopicQuery.new(current_user, build_topic_list_options)

      results = query.send("#{filter}_results").where(id: topics_tagged)

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


      if @list.topics.size == 0 && !TopicCustomField.where(name: DiscourseTagging::TAGS_FIELD_NAME, value: @tag_id).exists?
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

    new_tag_id = DiscourseTagging.clean_tag(params[:tag][:id])
    if current_user.staff?
      DiscourseTagging.rename_tag(current_user, params[:tag_id], new_tag_id)
    end
    render json: { tag: { id: new_tag_id }}
  end

  def destroy
    guardian.ensure_can_admin_tags!
    tag_id = params[:tag_id]
    TopicCustomField.transaction do
      TopicCustomField.where(name: DiscourseTagging::TAGS_FIELD_NAME, value: tag_id).delete_all
      UserCustomField.delete_all(name: ::DiscourseTagging.notification_key(tag_id))
      StaffActionLogger.new(current_user).log_custom('deleted_tag', subject: tag_id)
    end
    render json: success_json
  end

  def tag_feed
    discourse_expires_in 1.minute

    tag_id = ::DiscourseTagging.clean_tag(params[:tag_id])
    @link = "#{Discourse.base_url}/tags/#{tag_id}"
    @description = I18n.t("rss_by_tag", tag: tag_id)
    @title = "#{SiteSetting.title} - #{@description}"
    @atom_link = "#{Discourse.base_url}/tags/#{tag_id}.rss"

    query = TopicQuery.new(current_user)
    topics_tagged = TopicCustomField.where(name: DiscourseTagging::TAGS_FIELD_NAME, value: tag_id).pluck(:topic_id)
    latest_results = query.latest_results.where(id: topics_tagged)
    @topic_list = query.create_list(:by_tag, {}, latest_results)

    render 'list/list', formats: [:rss]
  end

  def search
    tags = self.class.tags_by_count(guardian, params.slice(:limit))
    term = params[:q]
    if term.present?
      term.gsub!(/[^a-z0-9\.\-\_]*/, '')
      term.gsub!("_", "\\_")
      tags = tags.where('value like ?', "%#{term}%")
    end

    tags = tags.count(:value).map {|t, c| { id: t, text: t, count: c } }

    render json: { results: tags }
  end

  def notifications
    level = current_user.custom_fields[::DiscourseTagging.notification_key(params[:tag_id])] || 1
    render json: { tag_notification: { id: params[:tag_id], notification_level: level.to_i } }
  end

  def update_notifications
    level = params[:tag_notification][:notification_level].to_i

    current_user.custom_fields[::DiscourseTagging.notification_key(params[:tag_id])] = level
    current_user.save_custom_fields

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

    def self.tags_by_count(guardian, opts=nil)
      opts = opts || {}
      result = TopicCustomField.where(name: DiscourseTagging::TAGS_FIELD_NAME)
                               .joins(:topic)
                               .group(:value)
                               .limit(opts[:limit] || 5)
                               .order('COUNT(topic_custom_fields.value) DESC')

      guardian.filter_allowed_categories(result)
    end

    def set_category_from_params
      slug_or_id = params[:category]
      return true if slug_or_id.nil?

      parent_slug_or_id = params[:parent_category]

      parent_category_id = nil
      if parent_slug_or_id.present?
        parent_category_id = Category.query_parent_category(parent_slug_or_id)
        raise Discourse::NotFound if parent_category_id.blank?
      end

      @filter_on_category = Category.query_category(slug_or_id, parent_category_id)
      raise Discourse::NotFound if !@filter_on_category

      guardian.ensure_can_see!(@filter_on_category)
    end

    def build_topic_list_options
      options = {
        page: params[:page],
        topic_ids: param_to_integer_list(:topic_ids),
        exclude_category_ids: params[:exclude_category_ids],
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
end
