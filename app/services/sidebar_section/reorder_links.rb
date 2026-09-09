# frozen_string_literal: true

class SidebarSection::ReorderLinks
  include Service::Base

  params do
    attribute :section_id, :integer
    attribute :links_order, :array

    before_validation do
      self.links_order = links_order&.filter_map { |link_id| Integer(link_id, exception: false) }
    end

    validates :section_id, presence: true
    validates :links_order, presence: true
  end

  model :section
  policy :can_edit_section
  policy :order_covers_every_link

  transaction do
    step :lock_section
    step :apply_order
  end

  only_if :public_section do
    step :publish_public_update
  end

  private

  def fetch_section(params:)
    SidebarSection.find_by(id: params.section_id)
  end

  def can_edit_section(guardian:, section:)
    guardian.can_edit?(section)
  end

  def order_covers_every_link(params:, section:)
    params.links_order.sort == section.sidebar_section_links.pluck(:linkable_id).sort
  end

  def lock_section(section:)
    section.lock!
  end

  def apply_order(params:, section:)
    section.apply_links_order!(params.links_order)
  end

  def public_section(section:)
    section.public?
  end

  def publish_public_update(guardian:, section:)
    StaffActionLogger.new(guardian.user).log_update_public_sidebar_section(section)
    MessageBus.publish("/refresh-sidebar-sections", nil)
    Site.clear_anon_cache!
  end
end
