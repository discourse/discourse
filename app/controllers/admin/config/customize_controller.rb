# frozen_string_literal: true

class Admin::Config::CustomizeController < Admin::AdminController
  def themes
  end

  def components
    offset = params[:offset]&.to_i
    components = Theme.include_relations.where(component: true).order(:name).limit(20)

    components = components.offset(offset * 20) if offset && offset > 0

    render json: { components: serialize_data(components, ComponentIndexSerializer) }
  end
end
