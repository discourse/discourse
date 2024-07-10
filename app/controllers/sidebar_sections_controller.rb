# frozen_string_literal: true

class SidebarSectionsController < ApplicationController
  requires_login
  before_action :check_access_if_public

  def index
    sections =
      SidebarSection
        .strict_loading
        .includes(:sidebar_urls)
        .where("public OR user_id = ?", current_user.id)
        .order("(public IS TRUE) DESC, title ASC")

    sections =
      ActiveModel::ArraySerializer.new(
        sections,
        each_serializer: SidebarSectionSerializer,
        scope: guardian,
        root: "sidebar_sections",
      )

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

    render_serialized(sidebar_section, SidebarSectionSerializer)
  rescue ActiveRecord::RecordInvalid => e
    render_json_error(e.record.errors.full_messages.first)
  rescue ActiveRecord::NestedAttributes::TooManyRecords => e
    render_json_error(e.message)
  end

  def update
    sidebar_section = SidebarSection.find_by(id: section_params["id"])
    @guardian.ensure_can_edit!(sidebar_section)

    ActiveRecord::Base.transaction do
      sidebar_section.update!(section_params.merge(sidebar_urls_attributes: links_params))
      sidebar_section.sidebar_section_links.update_all(user_id: sidebar_section.user_id)

      order =
        sidebar_section
          .sidebar_urls
          .sort_by do |url|
            links_params.index { |link| link["name"] == url.name && link["value"] == url.value } ||
              -1
          end
          .each_with_index
          .map { |url, index| [url.id, index] }
          .to_h

      set_order(sidebar_section, order)
    end

    if sidebar_section.public?
      StaffActionLogger.new(current_user).log_update_public_sidebar_section(sidebar_section)
      MessageBus.publish("/refresh-sidebar-sections", nil)
      Site.clear_anon_cache!
    end

    render_serialized(sidebar_section.reload, SidebarSectionSerializer)
  rescue ActiveRecord::RecordInvalid => e
    render_json_error(e.record.errors.full_messages.first)
  rescue ActiveRecord::NestedAttributes::TooManyRecords => e
    render_json_error(e.message)
  rescue Discourse::InvalidAccess
    render json: failed_json, status: 403
  end

  def reset
    sidebar_section = SidebarSection.find_by(id: params[:id])
    raise Discourse::InvalidParameters if !sidebar_section
    @guardian.ensure_can_edit!(sidebar_section)

    case sidebar_section.section_type
    when "community"
      sidebar_section.reset_community!
    end

    render_serialized(sidebar_section, SidebarSectionSerializer)
  end

  def destroy
    sidebar_section = SidebarSection.find_by(id: section_params["id"])
    @guardian.ensure_can_delete!(sidebar_section)
    sidebar_section.destroy!

    if sidebar_section.public?
      StaffActionLogger.new(current_user).log_destroy_public_sidebar_section(sidebar_section)
      MessageBus.publish("/refresh-sidebar-sections", nil)
    end

    render json: success_json
  rescue Discourse::InvalidAccess
    render json: failed_json, status: 403
  end

  def section_params
    section_params = params.permit(:id, :title, :public)
    section_params.merge!(user: current_user) if !params[:public]
    section_params
  end

  def links_params
    params.permit(links: %i[icon name value id _destroy segment])["links"]
  end

  def reorder_params
    params.permit(:sidebar_section_id, links_order: [])
  end

  private

  def set_order(sidebar_section, order)
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
  end

  def check_access_if_public
    return true if !params[:public]
    raise Discourse::InvalidAccess.new if !guardian.can_create_public_sidebar_section?
  end
end
