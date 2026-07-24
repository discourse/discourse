# frozen_string_literal: true

class SidebarSectionUpdater
  def self.update!(sidebar_section:, user:, section_params:, links_params:)
    new(sidebar_section:, user:, section_params:, links_params:).update!
  end

  def initialize(sidebar_section:, user:, section_params:, links_params:)
    @sidebar_section = sidebar_section
    @user = user
    @section_params = section_params
    @links_params = (links_params || []).map { |link| link.to_h.with_indifferent_access }
  end

  def update!
    ActiveRecord::Base.transaction do
      @sidebar_section.update!(@section_params.merge(sidebar_urls_attributes: @links_params))
      @sidebar_section.sidebar_section_links.update_all(user_id: @sidebar_section.user_id)
      update_link_order
    end

    publish_public_update if @sidebar_section.public?

    @sidebar_section
  end

  private

  def update_link_order
    order =
      @sidebar_section
        .sidebar_urls
        .sort_by do |url|
          @links_params.index { |link| link[:name] == url.name && link[:value] == url.value } || -1
        end
        .each_with_index
        .map { |url, index| [url.id, index] }
        .to_h

    set_order(order)
  end

  def set_order(order)
    position_generator =
      (0..@sidebar_section.sidebar_section_links.count * 2).excluding(
        @sidebar_section.sidebar_section_links.map(&:position),
      ).each

    links =
      @sidebar_section
        .sidebar_section_links
        .sort_by { |link| order[link.linkable_id] }
        .map { |link| link.attributes.merge(position: position_generator.next) }

    @sidebar_section.sidebar_section_links.upsert_all(links, update_only: [:position])
  end

  def publish_public_update
    StaffActionLogger.new(@user).log_update_public_sidebar_section(@sidebar_section)
    MessageBus.publish("/refresh-sidebar-sections", nil)
    Site.clear_anon_cache!
  end
end
