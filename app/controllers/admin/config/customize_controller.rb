# frozen_string_literal: true

class Admin::Config::CustomizeController < Admin::AdminController
  def themes
  end

  def components
    components = Theme.include_basic_relations.where(component: true).order(:name)

    name_search_term = params[:name].presence&.strip
    if name_search_term
      components = components.where("themes.name ILIKE ?", "%#{name_search_term}%")
    end

    status_filter = params[:status].presence
    if status_filter
      case status_filter
      when "used"
        components = components.joins(:parent_themes).distinct
      when "unused"
        components = components.left_joins(:parent_themes).where(parent_themes: { id: nil })
      when "updates_available"
        components = components.joins(:remote_theme).where(remote_theme: { commits_behind: 1.. })
      else
        raise Discourse::InvalidParameters if status_filter != "all"
      end
    end

    render json: { components: serialize_data(components, ComponentIndexSerializer) }
  end
end
