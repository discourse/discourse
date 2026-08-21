# frozen_string_literal: true

class SidebarSection::MoveLink
  include Service::Base

  params do
    attribute :source_section_id, :integer
    attribute :link_id, :integer
    attribute :target_section_id, :integer
    attribute :position, :integer

    validates :source_section_id, :link_id, :target_section_id, presence: true
    validates :position,
              numericality: {
                only_integer: true,
                greater_than_or_equal_to: 0,
              },
              allow_nil: true
  end

  model :source_section
  model :target_section
  policy :sections_are_distinct
  policy :can_edit_source_section
  policy :can_edit_target_section
  policy :target_section_has_room
  model :link

  transaction do
    step :lock_sections
    step :attach_link_to_target
    step :place_link
  end

  only_if :any_section_public do
    step :publish_public_update
  end

  private

  def fetch_source_section(params:)
    SidebarSection.find_by(id: params.source_section_id)
  end

  def fetch_target_section(params:)
    SidebarSection.find_by(id: params.target_section_id)
  end

  def sections_are_distinct(source_section:, target_section:)
    source_section.id != target_section.id
  end

  def can_edit_source_section(guardian:, source_section:)
    guardian.can_edit?(source_section)
  end

  def can_edit_target_section(guardian:, target_section:)
    guardian.can_edit?(target_section)
  end

  def target_section_has_room(target_section:)
    target_section.sidebar_section_links.count < SiteSetting.max_sidebar_section_links
  end

  def fetch_link(params:, source_section:)
    source_section.sidebar_section_links.find_by(
      linkable_type: "SidebarUrl",
      linkable_id: params.link_id,
    )
  end

  def lock_sections(source_section:, target_section:)
    SidebarSection.where(id: [source_section.id, target_section.id]).order(:id).lock.load
  end

  def attach_link_to_target(link:, target_section:)
    link.update!(
      sidebar_section: target_section,
      position: target_section.sidebar_section_links.maximum(:position).to_i + 1,
    )
  end

  def place_link(params:, link:, target_section:)
    ordered = target_section.sidebar_section_links.reload.map(&:linkable_id)
    ordered.delete(link.linkable_id)
    index = params.position ? [params.position, ordered.size].min : ordered.size
    ordered.insert(index, link.linkable_id)
    target_section.apply_links_order!(ordered)
  end

  def any_section_public(source_section:, target_section:)
    source_section.public? || target_section.public?
  end

  def publish_public_update(guardian:, source_section:, target_section:)
    [source_section, target_section].select(&:public?)
      .each do |section|
        StaffActionLogger.new(guardian.user).log_update_public_sidebar_section(section)
      end
    MessageBus.publish("/refresh-sidebar-sections", nil)
    Site.clear_anon_cache!
  end
end
