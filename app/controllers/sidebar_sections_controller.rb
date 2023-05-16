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

  def check_access_if_public
    return true if !params[:public]
    raise Discourse::InvalidAccess.new if !guardian.can_create_public_sidebar_section?
  end
end
