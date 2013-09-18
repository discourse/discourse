require_dependency 'category_serializer'

class CategoriesController < ApplicationController

  before_filter :ensure_logged_in, except: [:index, :show]
  before_filter :fetch_category, only: [:show, :update, :destroy]
  skip_before_filter :check_xhr, only: [:index]

  def index
    @description = SiteSetting.site_description

    @list = CategoryList.new(guardian)

    @list.draft_key = Draft::NEW_TOPIC
    @list.draft_sequence = DraftSequence.current(current_user, Draft::NEW_TOPIC)
    @list.draft = Draft.get(current_user, @list.draft_key, @list.draft_sequence) if current_user

    discourse_expires_in 1.minute

    store_preloaded("categories_list", MultiJson.dump(CategoryListSerializer.new(@list, scope: guardian)))
    respond_to do |format|
      format.html { render }
      format.json { render_serialized(@list, CategoryListSerializer) }
    end
  end

  def show
    render_serialized(@category, CategorySerializer)
  end

  def create
    guardian.ensure_can_create!(Category)

    @category = Category.create(category_params.merge(user: current_user))
    return render_json_error(@category) unless @category.save

    render_serialized(@category, CategorySerializer)
  end

  def update
    guardian.ensure_can_edit!(@category)
    json_result(@category, serializer: CategorySerializer) { |cat| cat.update_attributes(category_params) }
  end

  def destroy
    guardian.ensure_can_delete!(@category)
    @category.destroy
    render nothing: true
  end

  private

    def required_param_keys
      [:name, :color, :text_color]
    end

    def category_params
      required_param_keys.each do |key|
        params.require(key)
      end

      if p = params[:permissions]
        p.each do |k,v|
          p[k] = v.to_i
        end
      end

      params.permit(*required_param_keys, :hotness, :auto_close_days, :permissions => [*p.try(:keys)])
    end

    def fetch_category
      @category = Category.where(slug: params[:id]).first || Category.where(id: params[:id].to_i).first
    end
end
