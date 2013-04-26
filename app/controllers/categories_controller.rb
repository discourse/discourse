require_dependency 'category_serializer'

class CategoriesController < ApplicationController

  before_filter :ensure_logged_in, except: [:index, :show]
  before_filter :fetch_category, only: [:show, :update, :destroy]
  skip_before_filter :check_xhr, only: [:index]

  def index
    @list = CategoryList.new(current_user)
    discourse_expires_in 1.minute
    respond_to do |format|
      format.html { render }
      format.json { render_serialized(@list, CategoryListSerializer) }
    end
  end

  def show
    render_serialized(@category, CategorySerializer)
  end

  def create
    requires_parameters(*required_param_keys)
    guardian.ensure_can_create!(Category)

    @category = Category.create(category_params.merge(user: current_user))
    return render_json_error(@category) unless @category.save

    render_serialized(@category, CategorySerializer)
  end

  def update
    requires_parameters(*required_param_keys)
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

    def category_param_keys
      [required_param_keys, :hotness].flatten!
    end

    def category_params
      params.slice(*category_param_keys)
    end

    def fetch_category
      @category = Category.where(slug: params[:id]).first || Category.where(id: params[:id].to_i).first
    end
end
