require_dependency 'category_serializer'

class CategoriesController < ApplicationController

  before_filter :ensure_logged_in, except: [:index, :show, :redirect]
  before_filter :fetch_category, only: [:show, :update, :destroy]
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
    return render_json_error(@category) unless @category.save

    @category.move_to(position.to_i) if position
    render_serialized(@category, CategorySerializer)
  end

  def update
    guardian.ensure_can_edit!(@category)

    json_result(@category, serializer: CategorySerializer) do |cat|

      cat.move_to(category_params[:position].to_i) if category_params[:position]

      if category_params.key? :email_in and category_params[:email_in].length == 0
        # properly null the value so the database constrain doesn't catch us
        category_params[:email_in] = nil
      elsif category_params.key? :email_in and existing_category = Category.find_by(email_in: category_params[:email_in]) and existing_category.id != @category.id
        # check if email_in address is already in use for other category
        return render_json_error I18n.t('category.errors.email_in_already_exist', {email_in: category_params[:email_in], category_name: existing_category.name})
      end

      category_params.delete(:position)

      cat.update_attributes(category_params)
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

    render json: success_json
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
                        :allow_badges,
                        :slug,
                        :topic_template,
                        :custom_fields => [params[:custom_fields].try(:keys)],
                        :permissions => [*p.try(:keys)])
      end
    end

    def fetch_category
      @category = Category.find_by(slug: params[:id]) || Category.find_by(id: params[:id].to_i)
    end
end
