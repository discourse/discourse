# frozen_string_literal: true

module DiscourseDataExplorer
  class Mode
    CAPABILITIES = {
      "disabled" => {
        can_view_query_list: true,
        can_view_query_details: false,
        can_run_queries: false,
        can_create_queries: false,
        can_modify_queries: false,
      },
      "full" => {
        can_view_query_list: true,
        can_view_query_details: true,
        can_run_queries: true,
        can_create_queries: true,
        can_modify_queries: true,
      },
    }.freeze

    def self.capabilities
      CAPABILITIES[SiteSetting.data_explorer_mode]
    end

    def self.can?(capability)
      !!capabilities[capability]
    end

    def self.check_access!(*required_capabilities)
      required_capabilities.each { |cap| raise Discourse::InvalidAccess unless can?(cap) }
    end
  end
end
