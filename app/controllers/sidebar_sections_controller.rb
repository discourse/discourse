# frozen_string_literal: true

class SidebarSectionsController < ApplicationController
  requires_login
  before_action :check_if_member_of_group
  before_action :check_access_if_public

  def create
    sidebar_section =
      SidebarSection.create!(
        section_params.merge(user: current_user, sidebar_urls_attributes: links_params),
      )

    render json: SidebarSectionSerializer.new(sidebar_section)
  rescue ActiveRecord::RecordInvalid => e
    render_json_error(e.record.errors.full_messages.first)
  end

  def update
    sidebar_section = SidebarSection.find_by(id: section_params["id"])
    @guardian.ensure_can_edit!(sidebar_section)

    sidebar_section.update!(section_params.merge(sidebar_urls_attributes: links_params))

    render json: SidebarSectionSerializer.new(sidebar_section)
  rescue ActiveRecord::RecordInvalid => e
    render_json_error(e.record.errors.full_messages.first)
  rescue Discourse::InvalidAccess
    render json: failed_json, status: 403
  end

  def destroy
    sidebar_section = SidebarSection.find_by(id: section_params["id"])
    @guardian.ensure_can_delete!(sidebar_section)
    sidebar_section.destroy!
    render json: SidebarSectionSerializer.new(sidebar_section)
  rescue Discourse::InvalidAccess
    render json: failed_json, status: 403
  end

  def section_params
    params.permit(:id, :title, :public)
  end

  def links_params
    params.permit(links: %i[icon name value id _destroy])["links"]
  end

  def check_if_member_of_group
    ### TODO remove when enable_custom_sidebar_sections SiteSetting is removed
    if !SiteSetting.enable_custom_sidebar_sections.present? ||
         !current_user.in_any_groups?(SiteSetting.enable_custom_sidebar_sections_map)
      raise Discourse::InvalidAccess
    end
  end

  private

  def check_access_if_public
    return true if !params[:public]
    raise Discourse::InvalidAccess.new if !guardian.can_create_public_sidebar_section?
  end
end
