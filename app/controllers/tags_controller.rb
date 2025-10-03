# frozen_string_literal: true

class TagsController < ::ApplicationController
  include TopicListResponder
  include TopicQueryParams

  before_action :ensure_tags_enabled

  def self.show_methods
    Discourse.anonymous_filters.map { |f| :"show_#{f}" }
  end

  before_action :ensure_visible, only: [:show, :info, *show_methods]

  requires_login except: [:index, :show, :tag_feed, :search, :info, *show_methods]

  skip_before_action :check_xhr, only: [:tag_feed, :show, :index, *show_methods]

  before_action :set_category,
                except: %i[
                  index
                  update
                  destroy
                  tag_feed
                  search
                  notifications
                  update_notifications
                  personal_messages
                  info
                  list
                ]

  before_action :fetch_tag, only: %i[info create_synonyms destroy_synonym]

  after_action :add_noindex_header, except: %i[index show]

  def index
    @description_meta = I18n.t("tags.title")
    @title = @description_meta

    show_all_tags = guardian.can_admin_tags? && guardian.is_admin?

    if SiteSetting.tags_listed_by_group
      ungrouped_tags = Tag.where("tags.id NOT IN (SELECT tag_id FROM tag_group_memberships)")
      ungrouped_tags = ungrouped_tags.used_tags_in_regular_topics(guardian) unless show_all_tags
      ungrouped_tags = ungrouped_tags.order(:id)

      grouped_tag_counts =
        TagGroup
          .visible(guardian)
          .order("name ASC")
          .includes(:none_synonym_tags)
          .map do |tag_group|
            {
              id: tag_group.id,
              name: tag_group.name,
              tags: self.class.tag_counts_json(tag_group.none_synonym_tags, guardian),
            }
          end

      @tags = self.class.tag_counts_json(ungrouped_tags, guardian)
      @extras = { tag_groups: grouped_tag_counts }
    else
      tags = show_all_tags ? Tag.all : Tag.used_tags_in_regular_topics(guardian)
      tags = tags.order(:id)
      unrestricted_tags = DiscourseTagging.filter_visible(tags.where(target_tag_id: nil), guardian)

      categories =
        Category
          .where(
            "id IN (SELECT category_id FROM category_tags WHERE category_id IN (?))",
            guardian.allowed_category_ids,
          )
          .includes(:none_synonym_tags)
          .order(:id)

      category_tag_counts =
        categories
          .map do |c|
            category_tags =
              self.class.tag_counts_json(
                DiscourseTagging.filter_visible(c.none_synonym_tags, guardian),
                guardian,
              )

            next if category_tags.empty?

            { id: c.id, tags: category_tags }
          end
          .compact

      @tags = self.class.tag_counts_json(unrestricted_tags, guardian)
      @extras = { categories: category_tag_counts }
    end

    respond_to do |format|
      format.html { render :index }

      format.json { render json: { tags: @tags, extras: @extras } }
    end
  end

  LIST_LIMIT = 51

  def list
    offset = params[:offset].to_i || 0
    tags = guardian.can_admin_tags? ? Tag.all : Tag.visible(guardian)

    load_more_query_params = { offset: offset + 1 }

    if filter = params[:filter]
      tags = tags.where("LOWER(tags.name) ILIKE ?", "%#{filter.downcase}%")
      load_more_query_params[:filter] = filter
    end

    if only_tags = params[:only_tags]
      tags = tags.where("LOWER(tags.name) IN (?)", only_tags.split(",").map(&:downcase))
      load_more_query_params[:only_tags] = only_tags
    end

    if exclude_tags = params[:exclude_tags]
      tags = tags.where("LOWER(tags.name) NOT IN (?)", exclude_tags.split(",").map(&:downcase))
      load_more_query_params[:exclude_tags] = exclude_tags
    end

    tags_count = tags.count
    tags = tags.order("LOWER(tags.name) ASC").limit(LIST_LIMIT).offset(offset * LIST_LIMIT)

    load_more_url = URI("/tags/list.json")
    load_more_url.query = URI.encode_www_form(load_more_query_params)

    render_serialized(
      tags,
      TagSerializer,
      root: "list_tags",
      meta: {
        total_rows_list_tags: tags_count,
        load_more_list_tags: load_more_url.to_s,
      },
    )
  end

  Discourse.filters.each do |filter|
    define_method("show_#{filter}") do
      parent_tag_name =
        Tag
          .where_name(params[:tag_id])
          .where.not(target_tag_id: nil)
          .joins(
            "JOIN tags parent_tags ON parent_tags.id = tags.target_tag_id AND tags.target_tag_id != tags.id",
          )
          .pick("parent_tags.name")

      if parent_tag_name
        params[:tag_id] = parent_tag_name
        return redirect_to url_for(params.to_unsafe_hash)
      end

      @tag_id = params[:tag_id].force_encoding("UTF-8")
      @additional_tags =
        params[:additional_tag_ids].to_s.split("/").map { |t| t.force_encoding("UTF-8") }

      if @additional_tags.present?
        additional_tags_trimmed = @additional_tags.dup
        additional_tags_trimmed.delete(@tag_id)
        additional_tags_trimmed = additional_tags_trimmed&.uniq

        if additional_tags_trimmed != @additional_tags
          if additional_tags_trimmed.present?
            params[:additional_tag_ids] = additional_tags_trimmed&.join("/")
          else
            params[:additional_tag_ids] = nil
          end

          return redirect_to url_for(params.to_unsafe_hash)
        end
      end

      list_opts = build_topic_list_options
      @list = nil

      if filter == :top
        period = params[:period] || SiteSetting.top_page_default_timeframe.to_sym
        TopTopic.validate_period(period)

        @list = TopicQuery.new(current_user, list_opts).public_send("list_top_for", period)
        @list.for_period = period
      else
        @list = TopicQuery.new(current_user, list_opts).public_send("list_#{filter}")
      end

      @list.more_topics_url = construct_url_with(:next, list_opts)
      @list.prev_topics_url = construct_url_with(:prev, list_opts)
      @rss = "tag"
      @title = I18n.t("rss_by_tag", tag: tag_params.join(" & "))
      @description_meta = Tag.where(name: @tag_id).pick(:description) || @title

      canonical_params = params.slice(:category_slug_path_with_id, :tag_id)
      canonical_method = url_method(canonical_params)
      canonical_url "#{Discourse.base_url_no_prefix}#{public_send(canonical_method, *(canonical_params.values.map { |t| t.force_encoding("UTF-8") }))}"

      if @list.topics.size == 0 && params[:tag_id] != "none" && !Tag.where_name(@tag_id).exists?
        raise Discourse::NotFound.new("tag not found", check_permalinks: true)
      else
        respond_with_list(@list)
      end
    end
  end

  def show
    show_latest
  end

  def info
    render_serialized(@tag, DetailedTagSerializer, rest_serializer: true, root: :tag_info)
  end

  def update
    tag = Tag.find_by_name(params[:tag_id])
    raise Discourse::NotFound if tag.nil?

    guardian.ensure_can_edit_tag!(tag)

    if (params[:tag][:id].present?)
      new_tag_name = DiscourseTagging.clean_tag(params[:tag][:id])
      tag.name = new_tag_name
    end
    tag.description = params[:tag][:description] if params[:tag]&.has_key?(:description)
    if tag.save
      StaffActionLogger.new(current_user).log_custom(
        "renamed_tag",
        previous_value: params[:tag_id],
        new_value: new_tag_name,
      )
      render json: { tag: { id: tag.name, description: tag.description } }
    else
      render_json_error tag.errors.full_messages
    end
  end

  def upload
    require "csv"

    guardian.ensure_can_admin_tags!

    file = params[:file] || params[:files].first

    hijack do
      begin
        Tag.transaction do
          CSV.foreach(file.tempfile) do |row|
            if row.length > 2
              raise Discourse::InvalidParameters.new(I18n.t("tags.upload_row_too_long"))
            end

            tag_name = DiscourseTagging.clean_tag(row[0])
            tag_group_name = row[1] || nil

            tag = Tag.find_by_name(tag_name) || Tag.create!(name: tag_name)

            if tag_group_name
              tag_group =
                TagGroup.find_by(name: tag_group_name) || TagGroup.create!(name: tag_group_name)
              tag.tag_groups << tag_group if tag.tag_groups.exclude?(tag_group)
            end
          end
        end
        render json: success_json
      rescue Discourse::InvalidParameters => e
        render json: failed_json.merge(errors: [e.message]), status: 422
      end
    end
  end

  def list_unused
    guardian.ensure_can_admin_tags!
    render json: { tags: Tag.unused.pluck(:name) }
  end

  def destroy_unused
    guardian.ensure_can_admin_tags!
    tags = Tag.unused
    StaffActionLogger.new(current_user).log_custom("deleted_unused_tags", tags: tags.pluck(:name))
    tags.destroy_all
    render json: success_json
  end

  def destroy
    guardian.ensure_can_admin_tags!
    tag_name = params[:tag_id]
    tag = Tag.find_by_name(tag_name)
    raise Discourse::NotFound if tag.nil?

    TopicCustomField.transaction do
      tag.destroy
      StaffActionLogger.new(current_user).log_custom("deleted_tag", subject: tag_name)
    end
    render json: success_json
  end

  def tag_feed
    discourse_expires_in 1.minute

    tag_id = params[:tag_id]
    @link = "#{Discourse.base_url}/tag/#{tag_id}"
    @description = I18n.t("rss_by_tag", tag: tag_id)
    @title = "#{SiteSetting.title} - #{@description}"
    @atom_link = "#{Discourse.base_url}/tag/#{tag_id}.rss"

    query = TopicQuery.new(current_user, tags: [tag_id])
    latest_results = query.latest_results
    @topic_list = query.create_list(:by_tag, {}, latest_results)

    render "list/list", formats: [:rss]
  end

  def search
    filter_params = {
      for_input: params[:filterForInput],
      selected_tags: params[:selected_tags],
      exclude_synonyms: params[:excludeSynonyms],
      exclude_has_synonyms: params[:excludeHasSynonyms],
    }

    if limit = fetch_limit_from_params(default: nil, max: SiteSetting.max_tag_search_results)
      filter_params[:limit] = limit
    end

    filter_params[:category] = Category.find_by_id(params[:categoryId]) if params[:categoryId]

    if !params[:q].blank?
      clean_name = DiscourseTagging.clean_tag(params[:q])
      filter_params[:term] = clean_name
      filter_params[:order_search_results] = true
    else
      filter_params[:order_popularity] = true
    end

    tags_with_counts, filter_result_context =
      DiscourseTagging.filter_allowed_tags(guardian, **filter_params, with_context: true)

    tags = self.class.tag_counts_json(tags_with_counts, guardian)

    json_response = { results: tags }

    if clean_name && !tags.find { |h| h[:id].downcase == clean_name.downcase } &&
         tag = Tag.where_name(clean_name).first
      # filter_allowed_tags determined that the tag entered is not allowed
      json_response[:forbidden] = params[:q]

      if filter_params[:exclude_synonyms] && tag.synonym?
        json_response[:forbidden_message] = I18n.t(
          "tags.forbidden.synonym",
          tag_name: tag.target_tag.name,
        )
      elsif filter_params[:exclude_has_synonyms] && tag.synonyms.exists?
        json_response[:forbidden_message] = I18n.t(
          "tags.forbidden.has_synonyms",
          tag_name: tag.name,
        )
      else
        category_names = tag.categories.where(id: guardian.allowed_category_ids).pluck(:name)
        category_names +=
          Category
            .joins(tag_groups: :tags)
            .where(id: guardian.allowed_category_ids, "tags.id": tag.id)
            .pluck(:name)

        if category_names.present?
          category_names.uniq!
          json_response[:forbidden_message] = I18n.t(
            "tags.forbidden.restricted_to",
            count: category_names.count,
            tag_name: tag.name,
            category_names: category_names.join(", "),
          )
        else
          json_response[:forbidden_message] = I18n.t(
            "tags.forbidden.in_this_category",
            tag_name: tag.name,
          )
        end
      end
    end

    if required_tag_group = filter_result_context[:required_tag_group]
      json_response[:required_tag_group] = required_tag_group
    end

    render json: json_response
  end

  def notifications
    tag = Tag.where_name(params[:tag_id]).first
    raise Discourse::NotFound unless tag
    level =
      tag.tag_users.where(user: current_user).first.try(:notification_level) ||
        TagUser.notification_levels[:regular]
    render json: { tag_notification: { id: tag.name, notification_level: level.to_i } }
  end

  def update_notifications
    tag = Tag.find_by_name(params[:tag_id])
    raise Discourse::NotFound unless tag
    level = params[:tag_notification][:notification_level].to_i
    TagUser.change(current_user.id, tag.id, level)
    render_serialized(current_user, UserTagNotificationsSerializer, root: false)
  end

  def personal_messages
    guardian.ensure_can_tag_pms!
    allowed_user = fetch_user_from_params
    raise Discourse::NotFound if allowed_user.blank?
    raise Discourse::NotFound if current_user.id != allowed_user.id && !@guardian.is_admin?
    pm_tags = Tag.pm_tags(guardian: guardian, allowed_user: allowed_user)

    render json: { tags: pm_tags }
  end

  def create_synonyms
    guardian.ensure_can_edit_tag!
    value = DiscourseTagging.add_or_create_synonyms_by_name(@tag, params[:synonyms])
    if value.is_a?(Array)
      render json:
               failed_json.merge(
                 failed_tags:
                   value.inject({}) do |h, t|
                     h[t.name] = t.errors.full_messages.first
                     h
                   end,
               )
    else
      render json: success_json
    end
  end

  def destroy_synonym
    synonym = Tag.where_name(params[:synonym_id]).first
    raise Discourse::NotFound unless synonym

    guardian.ensure_can_edit_tag!(synonym)

    if synonym.target_tag == @tag
      synonym.update!(target_tag: nil)
      render json: success_json
    else
      render json: failed_json, status: 400
    end
  end

  private

  def fetch_tag
    @tag = Tag.find_by_name(params[:tag_id].force_encoding("UTF-8"))
    raise Discourse::NotFound unless @tag
  end

  def ensure_tags_enabled
    raise Discourse::NotFound unless SiteSetting.tagging_enabled?
  end

  def ensure_visible
    if DiscourseTagging.hidden_tag_names(guardian).include?(params[:tag_id])
      raise Discourse::NotFound
    end
  end

  def self.tag_counts_json(tags, guardian)
    show_pm_tags = guardian.can_tag_pms?
    target_tags = Tag.where(id: tags.map(&:target_tag_id).compact.uniq).select(:id, :name)

    tags
      .map do |t|
        topic_count = t.public_send(Tag.topic_count_column(guardian))

        next if topic_count == 0 && t.pm_topic_count > 0 && !show_pm_tags

        attrs = {
          id: t.name,
          text: t.name,
          name: t.name,
          description: t.description,
          count: topic_count,
          pm_only: topic_count == 0 && t.pm_topic_count > 0,
          target_tag:
            t.target_tag_id ? target_tags.find { |x| x.id == t.target_tag_id }&.name : nil,
        }

        if show_pm_tags && SiteSetting.display_personal_messages_tag_counts
          attrs[:pm_count] = t.pm_topic_count
        end

        attrs
      end
      .compact
  end

  def set_category
    if request.path_parameters.include?(:category_slug_path_with_id)
      @filter_on_category = Category.find_by_slug_path_with_id(params[:category_slug_path_with_id])
    else
      slug_or_id = params[:category]
      return true if slug_or_id.nil?

      @filter_on_category = Category.query_category(slug_or_id, nil)
    end

    if !@filter_on_category
      permalink = Permalink.find_by_url("c/#{params[:category_slug_path_with_id]}")
      if permalink.present? && permalink.category_id
        return(
          redirect_to "#{Discourse.base_path}/tags#{permalink.target_url}/#{params[:tag_id]}",
                      status: :moved_permanently
        )
      end
    end

    if !(@filter_on_category && guardian.can_see?(@filter_on_category))
      # 404 on 'access denied' to avoid leaking existence of category
      raise Discourse::NotFound
    end
  end

  def page_params
    route_params = { format: "json" }

    if @filter_on_category
      if request.path_parameters.include?(:category_slug_path_with_id)
        slug_path = @filter_on_category.slug_path

        route_params[:category_slug_path_with_id] = (
          slug_path + [@filter_on_category.id.to_s]
        ).join("/")
      else
        route_params[:category] = @filter_on_category.slug_for_url
      end
    end

    route_params
  end

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

  def url_method(opts = {})
    if opts[:category_slug_path_with_id]
      "tag_category_#{action_name}_path"
    else
      "tag_#{action_name}_path"
    end
  end

  def construct_url_with(action, opts)
    page_params =
      case action
      when :prev
        prev_page_params
      when :next
        next_page_params
      else
        raise "unreachable"
      end

    opts = opts.merge(page_params)
    opts.delete(:category) if opts.include?(:category_slug_path_with_id)

    method = url_method(opts)

    begin
      url = public_send(method, opts)
    rescue ActionController::UrlGenerationError
      raise Discourse::NotFound
    end

    url.sub(".json?", "?")
  end

  def build_topic_list_options
    options =
      super.merge(
        page: params[:page],
        topic_ids: param_to_integer_list(:topic_ids),
        category: @filter_on_category ? @filter_on_category.id : params[:category],
        order: params[:order],
        ascending: params[:ascending],
        min_posts: params[:min_posts],
        max_posts: params[:max_posts],
        status: params[:status],
        filter: params[:filter],
        state: params[:state],
        search: params[:search],
        q: params[:q],
      )
    options[:no_subcategories] = true if params[:no_subcategories] == true ||
      params[:no_subcategories] == "true"
    options[:per_page] = params[:per_page].to_i.clamp(1, 30) if params[:per_page].present?

    if params[:tag_id] == "none"
      options.delete(:tags)
      options[:no_tags] = true
    else
      options[:tags] = tag_params
      options[:match_all_tags] ||= true
    end

    options
  end

  def tag_params
    Array(params[:tags]).map(&:to_s).concat(Array(@additional_tags))
  end
end
