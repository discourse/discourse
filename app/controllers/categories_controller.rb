require_dependency 'category_serializer'

class CategoriesController < ApplicationController

  before_filter :ensure_logged_in, except: [:index, :show, :redirect, :find_by_slug]
  before_filter :fetch_category, only: [:show, :update, :destroy]
  before_filter :initialize_staff_action_logger, only: [:create, :update, :destroy]
  skip_before_filter :check_xhr, only: [:index, :redirect]

  def redirect
    redirect_to path("/c/#{params[:path]}")
  end

  def index
    @description = SiteSetting.site_description

    options = {}
    options[:latest_posts] = params[:latest_posts] || SiteSetting.category_featured_topics
    options[:parent_category_id] = params[:parent_category_id]
    options[:is_homepage] = current_homepage == "categories".freeze

    @list = CategoryList.new(guardian, options)
    @list.draft_key = Draft::NEW_TOPIC
    @list.draft_sequence = DraftSequence.current(current_user, Draft::NEW_TOPIC)
    @list.draft = Draft.get(current_user, @list.draft_key, @list.draft_sequence) if current_user

    discourse_expires_in 1.minute

    unless current_homepage == "categories"
      @title = I18n.t('js.filters.categories.title')
    end

    store_preloaded("categories_list", MultiJson.dump(CategoryListSerializer.new(@list, scope: guardian)))
    respond_to do |format|
      format.html { render }
      format.json { render_serialized(@list, CategoryListSerializer) }
    end
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
      raise Discourse::InvalidAccess unless by_category.keys.all? { |c| guardian.can_see_category? c }
    end

    by_category.each do |cat, pos|
      cat.position = pos
      cat.save if cat.position_changed?
    end
    render json: success_json
  end

  def show
    if Category.topic_create_allowed(guardian).where(id: @category.id).exists?
      @category.permission = CategoryGroup.permission_types[:full]
    end
    render_serialized(@category, CategorySerializer)
  end

  def create
    guardian.ensure_can_create!(Category)

    position = category_params.delete(:position)

    @category = Category.create(category_params.merge(user: current_user))

    if @category.save
      @category.move_to(position.to_i) if position

      Scheduler::Defer.later "Log staff action create category" do
        @staff_action_logger.log_category_creation(@category)
      end

      render_serialized(@category, CategorySerializer)
    else
      return render_json_error(@category) unless @category.save
    end
  end

  def update
    guardian.ensure_can_edit!(@category)

    json_result(@category, serializer: CategorySerializer) do |cat|

      cat.move_to(category_params[:position].to_i) if category_params[:position]
      category_params.delete(:position)

      # properly null the value so the database constraint doesn't catch us
      if category_params.has_key?(:email_in) && category_params[:email_in].blank?
        category_params[:email_in] = nil
      end

      old_permissions = cat.permissions_params

      if result = cat.update(category_params)
        Scheduler::Defer.later "Log staff action change category settings" do
          @staff_action_logger.log_category_settings_change(@category, category_params, old_permissions)
        end
      end

      result
    end
  end

  def update_slug
    @category = Category.find(params[:category_id].to_i)
    guardian.ensure_can_edit!(@category)

    custom_slug = params[:slug].to_s

    if custom_slug.present? && @category.update_attributes(slug: custom_slug)
      render json: success_json
    else
      render_json_error(@category)
    end
  end

  def set_notifications
    category_id = params[:category_id].to_i
    notification_level = params[:notification_level].to_i

    CategoryUser.set_notification_level_for_category(current_user, notification_level, category_id)
    render json: success_json
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
    @category = Category.find_by_slug(params[:category_slug], params[:parent_category_slug])
    guardian.ensure_can_see!(@category)

    @category.permission = CategoryGroup.permission_types[:full] if Category.topic_create_allowed(guardian).where(id: @category.id).exists?
    render_serialized(@category, CategorySerializer)
  end

  private

    def required_param_keys
      [:name, :color, :text_color]
    end

    def category_params
      @category_params ||= begin
        required_param_keys.each do |key|
          params.require(key)
        end

        if p = params[:permissions]
          p.each do |k,v|
            p[k] = v.to_i
          end
        end

        params[:allowed_tags] ||= [] if SiteSetting.tagging_enabled

        params.permit(*required_param_keys,
                        :position,
                        :email_in,
                        :email_in_allow_strangers,
                        :suppress_from_homepage,
                        :parent_category_id,
                        :auto_close_hours,
                        :auto_close_based_on_last_post,
                        :logo_url,
                        :background_url,
                        :slug,
                        :allow_badges,
                        :topic_template,
                        :custom_fields => [params[:custom_fields].try(:keys)],
                        :permissions => [*p.try(:keys)],
                        :allowed_tags => [])
      end
    end

    def fetch_category
      @category = Category.find_by(slug: params[:id]) || Category.find_by(id: params[:id].to_i)
    end

    def initialize_staff_action_logger
      @staff_action_logger = StaffActionLogger.new(current_user)
    end
end
