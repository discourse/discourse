# frozen_string_literal: true

class Admin::Config::CustomizeController < Admin::AdminController
  PAGE_SIZE = 20

  def themes
    themes =
      Theme
        .include_basic_relations
        .includes(:theme_fields, color_scheme: [:color_scheme_colors])
        .with_experimental_system_themes
        .where(component: false)
        .order(:name)

    render json: { themes: serialize_data(themes, ThemeIndexSerializer) }
  end

  def components
    page = params[:page]&.to_i

    components =
      Theme.include_basic_relations.where(component: true).order(:name).limit(PAGE_SIZE + 1)

    components = components.offset(page * PAGE_SIZE) if page && page > 0

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

    components = components.to_a
    has_more = components.size > PAGE_SIZE
    components = components[...PAGE_SIZE]

    render json: { has_more:, components: serialize_data(components, ComponentIndexSerializer) }
  end
end
