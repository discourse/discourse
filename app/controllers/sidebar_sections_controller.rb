# frozen_string_literal: true

class SidebarSectionsController < ApplicationController
  requires_login
  before_action :check_access_if_public

  def index
    sections =
      SidebarSection
        .strict_loading
        .includes(:localizations, sidebar_urls: :localizations)
        .where("public OR user_id = ?", current_user.id)
        .order("section_type IS NOT NULL DESC, public DESC, title ASC")

    sections =
      ActiveModel::ArraySerializer.new(
        sections,
        each_serializer: SidebarSectionSerializer,
        scope: guardian,
        root: "sidebar_sections",
      )

    render json: sections
  end

  def show
    sidebar_section =
      SidebarSection.includes(:localizations, sidebar_urls: :localizations).find(params[:id])
    @guardian.ensure_can_edit!(sidebar_section)

    render_serialized(sidebar_section, SidebarSectionEditSerializer, root: "sidebar_section")
  rescue Discourse::InvalidAccess
    render json: failed_json, status: :forbidden
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
    sidebar_section = SidebarSection.find(params[:id])
    @guardian.ensure_can_edit!(sidebar_section)
    ensure_localization_params_allowed(sidebar_section) if localization_params_present?
    permitted_section_params = section_params(sidebar_section)
    permitted_links_params = links_params(sidebar_section)

    SidebarSectionUpdater.update!(
      sidebar_section:,
      user: current_user,
      section_params: permitted_section_params,
      links_params: permitted_links_params,
    )

    render_serialized(sidebar_section.reload, SidebarSectionSerializer)
  rescue ActiveRecord::RecordInvalid => e
    render_json_error(e.record.errors.full_messages.first)
  rescue ActiveRecord::NestedAttributes::TooManyRecords => e
    render_json_error(e.message)
  rescue Discourse::InvalidAccess
    render json: failed_json, status: :forbidden
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
    sidebar_section = SidebarSection.find(section_params["id"])
    @guardian.ensure_can_delete!(sidebar_section)
    sidebar_section.destroy!

    if sidebar_section.public?
      StaffActionLogger.new(current_user).log_destroy_public_sidebar_section(sidebar_section)
      MessageBus.publish("/refresh-sidebar-sections", nil)
    end

    render json: success_json
  rescue Discourse::InvalidAccess
    render json: failed_json, status: :forbidden
  end

  def section_params(sidebar_section = nil)
    section_params = params.permit(:id, :title).to_h.with_indifferent_access

    if current_user.admin?
      section_params.merge!(params.permit(:public).to_h.with_indifferent_access)

      if SiteSetting.content_localization_enabled &&
           (sidebar_section.blank? || guardian.can_localize_sidebar_section_title?(sidebar_section))
        section_params.merge!(
          params
            .permit(:locale, localizations: %i[id locale title _destroy])
            .to_h
            .with_indifferent_access,
        )
      end
    end

    section_is_public = ActiveModel::Type::Boolean.new.cast(section_params[:public])
    section_params.merge!(user: current_user) if !section_is_public
    if section_params[:localizations]
      section_params[:localizations_attributes] = prepare_localization_attributes(
        section_params.delete(:localizations),
      )
    end
    section_params
  end

  def links_params(sidebar_section = nil)
    permitted_link_params = %i[icon name value id _destroy segment]
    if current_user.admin? && SiteSetting.content_localization_enabled
      permitted_link_params << { localizations: %i[id locale name _destroy] }
    end

    links = params.permit(links: permitted_link_params)["links"]

    links&.each do |link|
      next if link[:localizations].blank?
      if sidebar_section.present? &&
           !guardian.can_localize_sidebar_section_link?(sidebar_section, link[:value])
        link.delete(:localizations)
        next
      end

      link[:localizations_attributes] = prepare_localization_attributes(link.delete(:localizations))
    end

    links
  end

  def reorder_params
    params.permit(:sidebar_section_id, links_order: [])
  end

  private

  def check_access_if_public
    public_section = ActiveModel::Type::Boolean.new.cast(params[:public])
    return true if !public_section

    raise Discourse::InvalidAccess.new if !guardian.can_create_public_sidebar_section?
  end

  def localization_params_present?
    params[:localizations].present? || params[:links]&.any? { |link| link[:localizations].present? }
  end

  def ensure_localization_params_allowed(sidebar_section)
    if params[:localizations].present? &&
         !guardian.can_localize_sidebar_section_title?(sidebar_section)
      raise Discourse::InvalidAccess
    end

    params[:links]&.each do |link|
      next if link[:localizations].blank?
      next if guardian.can_localize_sidebar_section_link?(sidebar_section, link[:value])

      raise Discourse::InvalidAccess
    end
  end

  def prepare_localization_attributes(localizations)
    localizations.filter_map do |localization|
      destroy = ActiveModel::Type::Boolean.new.cast(localization[:_destroy])
      if !destroy && LocaleNormalizer.is_same?(localization[:locale], SiteSetting.default_locale)
        next
      end

      localization
    end
  end
end
