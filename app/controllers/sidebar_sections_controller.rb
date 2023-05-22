# frozen_string_literal: true

class SidebarSectionsController < ApplicationController
  requires_login
  before_action :check_access_if_public

  def index
    sections =
      SidebarSection
        .where("public OR user_id = ?", current_user.id)
        .order("(public IS TRUE) DESC")
        .map { |section| SidebarSectionSerializer.new(section, root: false) }
    render json: sections
  end

  def create
    sidebar_section =
      SidebarSection.create!(section_params.merge(sidebar_urls_attributes: links_params))

    if sidebar_section.public?
      StaffActionLogger.new(current_user).log_create_public_sidebar_section(sidebar_section)
      MessageBus.publish("/refresh-sidebar-sections", nil)
      Site.clear_anon_cache!
    end

    render json: SidebarSectionSerializer.new(sidebar_section)
  rescue ActiveRecord::RecordInvalid => e
    render_json_error(e.record.errors.full_messages.first)
  end

  def update
    sidebar_section = SidebarSection.find_by(id: section_params["id"])
    @guardian.ensure_can_edit!(sidebar_section)

    ActiveRecord::Base.transaction do
      sidebar_section.update!(section_params.merge(sidebar_urls_attributes: links_params))
      sidebar_section.sidebar_section_links.update_all(user_id: sidebar_section.user_id)
    end

    if sidebar_section.public?
      StaffActionLogger.new(current_user).log_update_public_sidebar_section(sidebar_section)
      MessageBus.publish("/refresh-sidebar-sections", nil)
      Site.clear_anon_cache!
    end

    render json: SidebarSectionSerializer.new(sidebar_section)
  rescue ActiveRecord::RecordInvalid => e
    render_json_error(e.record.errors.full_messages.first)
  rescue Discourse::InvalidAccess
    render json: failed_json, status: 403
  end

  def reset
    sidebar_section = SidebarSection.find(params[:id])
    @guardian.ensure_can_edit!(sidebar_section)

    case sidebar_section.section_type
    when "community"
      reset_community(sidebar_section)
    end
    render_serialized(sidebar_section.reload, SidebarSectionSerializer)
  end

  def reorder
    sidebar_section = SidebarSection.find_by(id: reorder_params["sidebar_section_id"])
    @guardian.ensure_can_edit!(sidebar_section)

    order = reorder_params["links_order"].map(&:to_i).each_with_index.to_h
    position_generator =
      (0..sidebar_section.sidebar_section_links.count * 2).excluding(
        sidebar_section.sidebar_section_links.map(&:position),
      ).each
    links =
      sidebar_section
        .sidebar_section_links
        .sort_by { |link| order[link.linkable_id] }
        .map { |link| link.attributes.merge(position: position_generator.next) }
    sidebar_section.sidebar_section_links.upsert_all(links, update_only: [:position])
    render json: sidebar_section
  rescue Discourse::InvalidAccess
    render json: failed_json, status: 403
  end

  def destroy
    sidebar_section = SidebarSection.find_by(id: section_params["id"])
    @guardian.ensure_can_delete!(sidebar_section)
    sidebar_section.destroy!

    if sidebar_section.public?
      StaffActionLogger.new(current_user).log_destroy_public_sidebar_section(sidebar_section)
      MessageBus.publish("/refresh-sidebar-sections", nil)
    end
    render json: SidebarSectionSerializer.new(sidebar_section)
  rescue Discourse::InvalidAccess
    render json: failed_json, status: 403
  end

  def section_params
    section_params = params.permit(:id, :title, :public)
    section_params.merge!(user: current_user) if !params[:public]
    section_params
  end

  def links_params
    params.permit(links: %i[icon name value id _destroy])["links"]
  end

  def reorder_params
    params.permit(:sidebar_section_id, links_order: [])
  end

  private

  def reset_community(community_section)
    community_section.update!(title: "Community")
    community_section.sidebar_section_links.destroy_all
    community_urls =
      SidebarUrl::COMMUNITY_SECTION_LINKS.map do |url_data|
        "('#{url_data[:name]}', '#{url_data[:path]}', '#{url_data[:icon]}', '#{url_data[:segment]}', false, now(), now())"
      end

    result = DB.query <<~SQL
      INSERT INTO sidebar_urls(name, value, icon, segment, external, created_at, updated_at)
      VALUES #{community_urls.join(",")}
      RETURNING sidebar_urls.id
    SQL

    sidebar_section_links =
      result.map.with_index do |url, index|
        "(-1, #{url.id}, 'SidebarUrl', #{community_section.id}, #{index},  now(), now())"
      end

    DB.query <<~SQL
      INSERT INTO sidebar_section_links(user_id, linkable_id, linkable_type, sidebar_section_id, position, created_at, updated_at)
      VALUES #{sidebar_section_links.join(",")}
    SQL
  end

  def check_access_if_public
    return true if !params[:public]
    raise Discourse::InvalidAccess.new if !guardian.can_create_public_sidebar_section?
  end
end
