# frozen_string_literal: true

module AdPlugin
  class HouseAdSerializer < ApplicationSerializer
    attributes :id,
               :name,
               :html,
               :visible_to_logged_in_users,
               :visible_to_anons,
               :created_at,
               :updated_at,
               :routes

    has_many :groups, serializer: ::BasicGroupSerializer, embed: :objects
    has_many :categories, serializer: ::BasicCategorySerializer, embed: :objects

    def routes
      object.route_names
    end

    def include_routes?
      SiteSetting.ad_plugin_routes_enabled
    end

    def include_groups?
      @options[:include_groups]
    end

    def include_categories?
      @options[:include_categories]
    end
  end
end
