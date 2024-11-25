# frozen_string_literal: true

class CategoriesController < ApplicationController
  include TopicQueryParams

  requires_login except: %i[
                   index
                   categories_and_latest
                   categories_and_top
                   show
                   redirect
                   find_by_slug
                   visible_groups
                   find
                   search
                 ]

  before_action :fetch_category, only: %i[show update destroy visible_groups]
  before_action :initialize_staff_action_logger, only: %i[create update destroy]
  skip_before_action :check_xhr, only: %i[index categories_and_latest categories_and_top redirect]
  skip_before_action :verify_authenticity_token, only: %i[search]

  SYMMETRICAL_CATEGORIES_TO_TOPICS_FACTOR = 1.5
  MIN_CATEGORIES_TOPICS = 5
  MAX_CATEGORIES_LIMIT = 25

  def redirect
    return if handle_permalink("/category/#{params[:path]}")
    redirect_to path("/c/#{params[:path]}")
  end

  def index
    discourse_expires_in 1.minute

    @category_list = fetch_category_list

    respond_to do |format|
      format.html do
        @title =
          if current_homepage == "categories" && SiteSetting.short_site_description.present?
            "#{SiteSetting.title} - #{SiteSetting.short_site_description}"
          elsif current_homepage != "categories"
            "#{I18n.t("js.filters.categories.title")} - #{SiteSetting.title}"
          end

        @description = SiteSetting.site_description

        store_preloaded(
          @category_list.preload_key,
          MultiJson.dump(CategoryListSerializer.new(@category_list, scope: guardian)),
        )

        @topic_list = fetch_topic_list

        if @topic_list.present? && @topic_list.topics.present?
          store_preloaded(
            @topic_list.preload_key,
            MultiJson.dump(TopicListSerializer.new(@topic_list, scope: guardian)),
          )
        end

        render
      end

      format.json { render_serialized(@category_list, CategoryListSerializer) }
    end
  end

  def categories_and_latest
    categories_and_topics(:latest)
  end

  def categories_and_top
    categories_and_topics(:top)
  end

  def move
    guardian.ensure_can_create_category!

    params.require("category_id")
    params.require("position")

    if category = Category.find(params["category_id"])
      category.move_to(params["position"].to_i)
      render json: success_json
    else
      render status: 500, json: failed_json
    end
  end

  def reorder
    guardian.ensure_can_create_category!

    params.require(:mapping)
    change_requests = MultiJson.load(params[:mapping])
    by_category = Hash[change_requests.map { |cat, pos| [Category.find(cat.to_i), pos] }]

    unless guardian.is_admin?
      unless by_category.keys.all? { |c| guardian.can_see_category? c }
        raise Discourse::InvalidAccess
      end
    end

    by_category.each do |cat, pos|
      cat.position = pos
      cat.save! if cat.will_save_change_to_position?
    end

    render json: success_json
  end

  def show
    guardian.ensure_can_see!(@category)

    if Category.topic_create_allowed(guardian).where(id: @category.id).exists?
      @category.permission = CategoryGroup.permission_types[:full]
    end

    render_serialized(@category, CategorySerializer)
  end

  def create
    guardian.ensure_can_create!(Category)
    position = category_params.delete(:position)

    @category =
      begin
        Category.new(required_create_params.merge(user: current_user))
      rescue ArgumentError => e
        return render json: { errors: [e.message] }, status: 422
      end

    if @category.save
      @category.move_to(position.to_i) if position

      Scheduler::Defer.later "Log staff action create category" do
        @staff_action_logger.log_category_creation(@category)
      end

      render_serialized(@category, CategorySerializer)
    else
      render_json_error(@category)
    end
  end

  def update
    guardian.ensure_can_edit!(@category)

    json_result(@category, serializer: CategorySerializer) do |cat|
      old_category_params = category_params.dup

      cat.move_to(category_params[:position].to_i) if category_params[:position]
      category_params.delete(:position)

      old_custom_fields = cat.custom_fields.dup
      if category_params[:custom_fields]
        category_params[:custom_fields].each do |key, value|
          if value.present?
            cat.custom_fields[key] = value
          else
            cat.custom_fields.delete(key)
          end
        end
      end
      category_params.delete(:custom_fields)

      # properly null the value so the database constraint doesn't catch us
      category_params[:email_in] = nil if category_params[:email_in].blank?
      category_params[:minimum_required_tags] = 0 if category_params[:minimum_required_tags].blank?

      old_permissions = cat.permissions_params
      old_permissions = { "everyone" => 1 } if old_permissions.empty?

      if result = cat.update(category_params)
        Scheduler::Defer.later "Log staff action change category settings" do
          @staff_action_logger.log_category_settings_change(
            @category,
            old_category_params,
            old_permissions: old_permissions,
            old_custom_fields: old_custom_fields,
          )
        end
      end

      DiscourseEvent.trigger(:category_updated, cat) if result

      result
    end
  end

  def update_slug
    @category = Category.find(params[:category_id].to_i)
    guardian.ensure_can_edit!(@category)

    custom_slug = params[:slug].to_s

    if custom_slug.blank?
      error = @category.errors.full_message(:slug, I18n.t("errors.messages.blank"))
      render_json_error(error)
    elsif @category.update(slug: custom_slug)
      render json: success_json
    else
      render_json_error(@category)
    end
  end

  def set_notifications
    category_id = params[:category_id].to_i
    notification_level = params[:notification_level].to_i

    CategoryUser.set_notification_level_for_category(current_user, notification_level, category_id)
    render json:
             success_json.merge(
               {
                 indirectly_muted_category_ids:
                   CategoryUser.indirectly_muted_category_ids(current_user),
               },
             )
  end

  def destroy
    guardian.ensure_can_delete!(@category)
    @category.destroy

    Scheduler::Defer.later "Log staff action delete category" do
      @staff_action_logger.log_category_deletion(@category)
    end

    render json: success_json
  end

  def find_by_slug
    params.require(:category_slug)
    @category =
      Category.includes(:category_setting).find_by_slug_path(params[:category_slug].split("/"))

    raise Discourse::NotFound if @category.blank?

    if !guardian.can_see?(@category)
      if SiteSetting.detailed_404 && group = @category.access_category_via_group
        raise Discourse::InvalidAccess.new(
                "not in group",
                @category,
                custom_message: "not_in_group.title_category",
                custom_message_params: {
                  group: group.name,
                },
                group: group,
              )
      else
        raise Discourse::NotFound
      end
    end

    @category.permission = CategoryGroup.permission_types[:full] if Category
      .topic_create_allowed(guardian)
      .where(id: @category.id)
      .exists?
    render_serialized(@category, CategorySerializer)
  end

  def visible_groups
    @guardian.ensure_can_see!(@category)

    groups =
      if !@category.groups.exists?(id: Group::AUTO_GROUPS[:everyone])
        @category.groups.merge(Group.visible_groups(current_user)).pluck("name")
      end

    render json: success_json.merge(groups: groups || [])
  end

  def find
    categories = []
    serializer = params[:include_permissions] ? CategorySerializer : SiteCategorySerializer

    if params[:ids].present?
      categories = Category.secured(guardian).where(id: params[:ids])
    elsif params[:slug_path].present?
      category = Category.find_by_slug_path(params[:slug_path].split("/"))
      raise Discourse::NotFound if category.blank?
      guardian.ensure_can_see!(category)

      ancestors = Category.secured(guardian).with_ancestors(category.id).where.not(id: category.id)
      categories = [*ancestors, category]
    elsif params[:slug_path_with_id].present?
      category = Category.find_by_slug_path_with_id(params[:slug_path_with_id])
      raise Discourse::NotFound if category.blank?
      guardian.ensure_can_see!(category)

      ancestors = Category.secured(guardian).with_ancestors(category.id).where.not(id: category.id)
      categories = [*ancestors, category]
    end

    raise Discourse::NotFound if categories.blank?

    Category.preload_user_fields!(guardian, categories)

    render_serialized(categories, serializer, root: :categories, scope: guardian)
  end

  def hierarchical_search
    term = params[:term].to_s.strip
    page = [1, params[:page].to_i].max
    offset = params[:offset].to_i
    parent_category_id = params[:parent_category_id].to_i if params[:parent_category_id].present?
    only =
      if params[:only].present?
        Category.secured(guardian).where(id: params[:only].to_a.map(&:to_i))
      else
        Category.secured(guardian)
      end
    except_ids = params[:except].to_a.map(&:to_i)
    include_uncategorized =
      (
        if params[:include_uncategorized].present?
          ActiveModel::Type::Boolean.new.cast(params[:include_uncategorized])
        else
          true
        end
      )

    except_ids << SiteSetting.uncategorized_category_id unless include_uncategorized

    except = Category.where(id: except_ids) if except_ids.present?

    limit =
      (
        if params[:limit].present?
          params[:limit].to_i.clamp(1, MAX_CATEGORIES_LIMIT)
        else
          MAX_CATEGORIES_LIMIT
        end
      )

    categories =
      Category
        .secured(guardian)
        .limited_categories_matching(only, except, parent_category_id, term)
        .preload(
          :uploaded_logo,
          :uploaded_logo_dark,
          :uploaded_background,
          :uploaded_background_dark,
          :tags,
          :tag_groups,
          :form_templates,
          category_required_tag_groups: :tag_group,
        )
        .joins("LEFT JOIN topics t on t.id = categories.topic_id")
        .select("categories.*, t.slug topic_slug")
        .limit(limit)
        .offset((page - 1) * limit + offset)
        .to_a

    if Site.preloaded_category_custom_fields.present?
      Category.preload_custom_fields(categories, Site.preloaded_category_custom_fields)
    end

    Category.preload_user_fields!(guardian, categories)

    response = { categories: serialize_data(categories, SiteCategorySerializer, scope: guardian) }

    render_json_dump(response)
  end

  def search
    term = params[:term].to_s.strip
    parent_category_id = params[:parent_category_id].to_i if params[:parent_category_id].present?
    include_uncategorized =
      (
        if params[:include_uncategorized].present?
          ActiveModel::Type::Boolean.new.cast(params[:include_uncategorized])
        else
          true
        end
      )
    if params[:select_category_ids].is_a?(Array)
      select_category_ids = params[:select_category_ids].map(&:presence)
    end
    if params[:reject_category_ids].is_a?(Array)
      reject_category_ids = params[:reject_category_ids].map(&:presence)
    end
    include_subcategories =
      if params[:include_subcategories].present?
        ActiveModel::Type::Boolean.new.cast(params[:include_subcategories])
      else
        true
      end
    include_ancestors =
      if params[:include_ancestors].present?
        ActiveModel::Type::Boolean.new.cast(params[:include_ancestors])
      else
        false
      end
    prioritized_category_id = params[:prioritized_category_id].to_i if params[
      :prioritized_category_id
    ].present?
    limit =
      (
        if params[:limit].present?
          params[:limit].to_i.clamp(1, MAX_CATEGORIES_LIMIT)
        else
          MAX_CATEGORIES_LIMIT
        end
      )
    page = [1, params[:page].to_i].max

    categories = Category.secured(guardian)

    if term.present? && words = term.split
      words.each { |word| categories = categories.where("name ILIKE ?", "%#{word}%") }
    end

    categories =
      (
        if parent_category_id != -1
          categories.where(parent_category_id: parent_category_id)
        else
          categories.where(parent_category_id: nil)
        end
      ) if parent_category_id.present?

    categories =
      categories.where.not(id: SiteSetting.uncategorized_category_id) if !include_uncategorized

    categories = categories.where(id: select_category_ids) if select_category_ids

    categories = categories.where.not(id: reject_category_ids) if reject_category_ids

    categories = categories.where(parent_category_id: nil) if !include_subcategories

    categories_count = categories.count

    categories =
      categories
        .includes(
          :uploaded_logo,
          :uploaded_logo_dark,
          :uploaded_background,
          :uploaded_background_dark,
          :tags,
          :tag_groups,
          :form_templates,
          category_required_tag_groups: :tag_group,
        )
        .joins("LEFT JOIN topics t on t.id = categories.topic_id")
        .select("categories.*, t.slug topic_slug")
        .order(
          "starts_with(lower(categories.name), #{ActiveRecord::Base.connection.quote(term)}) DESC",
          "categories.parent_category_id IS NULL DESC",
          "categories.id IS NOT DISTINCT FROM #{ActiveRecord::Base.connection.quote(prioritized_category_id)} DESC",
          "categories.parent_category_id IS NOT DISTINCT FROM #{ActiveRecord::Base.connection.quote(prioritized_category_id)} DESC",
          "categories.id ASC",
        )
        .limit(limit)
        .offset((page - 1) * limit)

    if Site.preloaded_category_custom_fields.present?
      Category.preload_custom_fields(categories, Site.preloaded_category_custom_fields)
    end

    Category.preload_user_fields!(guardian, categories)

    response = {
      categories_count: categories_count,
      categories: serialize_data(categories, SiteCategorySerializer, scope: guardian),
    }

    if include_ancestors
      ancestors = Category.secured(guardian).ancestors_of(categories.map(&:id))
      Category.preload_user_fields!(guardian, ancestors)
      response[:ancestors] = serialize_data(ancestors, SiteCategorySerializer, scope: guardian)
    end

    render_json_dump(response)
  end

  private

  def self.topics_per_page
    return SiteSetting.categories_topics if SiteSetting.categories_topics > 0

    count = Category.where(parent_category: nil).count
    count = (SYMMETRICAL_CATEGORIES_TO_TOPICS_FACTOR * count).to_i
    count > MIN_CATEGORIES_TOPICS ? count : MIN_CATEGORIES_TOPICS
  end

  def categories_and_topics(topics_filter)
    discourse_expires_in 1.minute

    result = CategoryAndTopicLists.new
    result.category_list = fetch_category_list
    result.topic_list = fetch_topic_list(topics_filter:)

    render_serialized(result, CategoryAndTopicListsSerializer, root: false)
  end

  def required_param_keys
    [:name]
  end

  def required_create_params
    required_param_keys.each { |key| params.require(key) }
    category_params
  end

  def category_params
    @category_params ||=
      begin
        if p = params[:permissions]
          p.each { |k, v| p[k] = v.to_i }
        end

        if SiteSetting.tagging_enabled
          params[:allowed_tags] = params[:allowed_tags].presence || [] if params[:allowed_tags]
          params[:allowed_tag_groups] = params[:allowed_tag_groups].presence || [] if params[
            :allowed_tag_groups
          ]
          params[:required_tag_groups] = params[:required_tag_groups].presence || [] if params[
            :required_tag_groups
          ]
        end

        conditional_param_keys = []
        if SiteSetting.enable_category_group_moderation?
          conditional_param_keys << { moderating_group_ids: [] }
        end

        result =
          params.permit(
            *required_param_keys,
            :position,
            :name,
            :color,
            :text_color,
            :email_in,
            :email_in_allow_strangers,
            :mailinglist_mirror,
            :all_topics_wiki,
            :allow_unlimited_owner_edits_on_first_post,
            :default_slow_mode_seconds,
            :parent_category_id,
            :auto_close_hours,
            :auto_close_based_on_last_post,
            :uploaded_logo_id,
            :uploaded_logo_dark_id,
            :uploaded_background_id,
            :uploaded_background_dark_id,
            :slug,
            :allow_badges,
            :topic_template,
            :sort_order,
            :sort_ascending,
            :topic_featured_link_allowed,
            :show_subcategory_list,
            :num_featured_topics,
            :default_view,
            :subcategory_list_style,
            :default_top_period,
            :minimum_required_tags,
            :navigate_to_first_post_after_read,
            :search_priority,
            :allow_global_tags,
            :read_only_banner,
            :default_list_filter,
            *conditional_param_keys,
            category_setting_attributes: %i[
              auto_bump_cooldown_days
              num_auto_bump_daily
              require_reply_approval
              require_topic_approval
            ],
            custom_fields: [custom_field_params],
            permissions: [*p.try(:keys)],
            allowed_tags: [],
            allowed_tag_groups: [],
            required_tag_groups: %i[name min_count],
            form_template_ids: [],
          )

        if result[:required_tag_groups] && !result[:required_tag_groups].is_a?(Array)
          raise Discourse::InvalidParameters.new(:required_tag_groups)
        end

        result
      end
  end

  def custom_field_params
    keys = params[:custom_fields].try(:keys)
    return if keys.blank?

    keys.map { |key| params[:custom_fields][key].is_a?(Array) ? { key => [] } : key }
  end

  def fetch_category
    @category = Category.find_by_slug(params[:id]) || Category.find_by(id: params[:id].to_i)
    raise Discourse::NotFound if @category.blank?
  end

  def fetch_category_list
    parent_category =
      if params[:parent_category_id].present?
        Category.find_by_slug(params[:parent_category_id]) ||
          Category.find_by(id: params[:parent_category_id].to_i)
      elsif params[:category_slug_path_with_id].present?
        Category.find_by_slug_path_with_id(params[:category_slug_path_with_id])
      end

    include_topics =
      view_context.mobile_view? || params[:include_topics] ||
        (parent_category && parent_category.subcategory_list_includes_topics?) ||
        SiteSetting.desktop_category_page_style == "categories_with_featured_topics" ||
        SiteSetting.desktop_category_page_style == "subcategories_with_featured_topics" ||
        SiteSetting.desktop_category_page_style == "categories_boxes_with_topics" ||
        SiteSetting.desktop_category_page_style == "categories_with_top_topics"

    include_subcategories =
      SiteSetting.desktop_category_page_style == "subcategories_with_featured_topics" ||
        params[:include_subcategories] == "true"

    category_options = {
      is_homepage: current_homepage == "categories",
      parent_category_id: parent_category&.id,
      include_topics: include_topics,
      include_subcategories: include_subcategories,
      tag: params[:tag],
      page: params[:page].try(:to_i) || 1,
    }

    @category_list = CategoryList.new(guardian, category_options)
  end

  def fetch_topic_list(topics_filter: nil)
    style =
      if topics_filter
        "categories_and_#{topics_filter}_topics"
      else
        SiteSetting.desktop_category_page_style
      end

    topic_options = { per_page: CategoriesController.topics_per_page, no_definitions: true }
    topic_options.merge!(build_topic_list_options)
    topic_options[:order] = "created" if SiteSetting.desktop_category_page_style ==
      "categories_and_latest_topics_created_date"

    case style
    when "categories_and_latest_topics", "categories_and_latest_topics_created_date"
      @topic_list = TopicQuery.new(current_user, topic_options).list_latest
      @topic_list.more_topics_url = url_for(latest_path(sort: topic_options[:order]))
    when "categories_and_top_topics"
      @topic_list =
        TopicQuery.new(current_user, topic_options).list_top_for(
          SiteSetting.top_page_default_timeframe.to_sym,
        )
      @topic_list.more_topics_url = url_for(top_path)
    end

    @topic_list
  end

  def initialize_staff_action_logger
    @staff_action_logger = StaffActionLogger.new(current_user)
  end
end
