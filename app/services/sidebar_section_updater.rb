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
    @sidebar_section.with_lock do
      @sidebar_section.assign_attributes(
        @section_params.merge(sidebar_urls_attributes: @links_params),
      )
      @sidebar_section.save!(context: :sidebar_section_update)
      @sidebar_section.sidebar_section_links.update_all(user_id: @sidebar_section.user_id)
      update_link_order
    end

    publish_public_update if @sidebar_section.public?

    @sidebar_section
  end

  private

  def update_link_order
    ordered_linkable_ids =
      @sidebar_section
        .sidebar_urls
        .sort_by do |url|
          @links_params.index { |link| link[:name] == url.name && link[:value] == url.value } || -1
        end
        .map(&:id)

    @sidebar_section.apply_links_order!(ordered_linkable_ids)
  end

  def publish_public_update
    StaffActionLogger.new(@user).log_update_public_sidebar_section(@sidebar_section)
    MessageBus.publish("/refresh-sidebar-sections", nil)
    Site.clear_anon_cache!
  end
end
