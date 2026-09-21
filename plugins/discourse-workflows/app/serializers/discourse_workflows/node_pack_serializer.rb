# frozen_string_literal: true

module DiscourseWorkflows
  class NodePackSerializer < ApplicationSerializer
    attributes :id,
               :key,
               :name,
               :version,
               :description,
               :icon,
               :color,
               :enabled,
               :palette_visible,
               :node_count,
               :retired_count,
               :used_by_count,
               :destinations,
               :installed_by,
               :updated_at

    def description
      object.manifest["description"]
    end

    def icon
      object.manifest["icon"]
    end

    def color
      object.manifest["color"]
    end

    def node_count
      definitions.count { |definition| definition.retired_at.nil? }
    end

    def retired_count
      definitions.count { |definition| definition.retired_at.present? }
    end

    def used_by_count
      @options[:usage_count] || usage.length
    end

    def destinations
      historical =
        definitions.flat_map do |definition|
          Array(definition.definition.dig("_effective", "approved_origins"))
        end
      (object.approved_destinations + historical).uniq
    end

    def installed_by
      user = object.installed_by
      { id: user.id, username: user.username } if user
    end

    private

    def definitions
      object.association(:definitions).loaded? ? object.definitions.target : object.definitions.to_a
    end

    def usage
      @options[:usage] || NodePacks::UsageQuery.new(definitions.map(&:identifier)).workflows
    end
  end
end
