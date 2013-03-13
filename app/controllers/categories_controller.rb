require_dependency 'category_serializer'

class CategoriesController < ApplicationController

  before_filter :ensure_logged_in, except: [:index, :show]

  def index
    list = CategoryList.new(current_user)
    render_serialized(list, CategoryListSerializer)
  end

  def show
    @category = Category.where(slug: params[:id]).first
    render_serialized(@category, CategorySerializer)
  end

  def create
    requires_parameters(*category_param_keys)
    guardian.ensure_can_create!(Category)

    @category = Category.create(category_params.merge(user: current_user))
    return render_json_error(@category) unless @category.save

    render_serialized(@category, CategorySerializer)
  end

  def update
    requires_parameters(*category_param_keys)

    @category = Category.where(id: params[:id]).first
    guardian.ensure_can_edit!(@category)

    json_result(@category, serializer: CategorySerializer) { |cat| cat.update_attributes(category_params) }
  end

  def destroy
    category = Category.where(slug: params[:id]).first
    guardian.ensure_can_delete!(category)
    category.destroy
    render nothing: true
  end

  private

    def category_param_keys
      [:name, :color]
    end

    def category_params
      params.slice(*category_param_keys)
    end
end
