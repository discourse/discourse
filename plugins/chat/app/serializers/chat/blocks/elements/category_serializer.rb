# frozen_string_literal: true

module Chat
  module Blocks
    module Elements
      class CategorySerializer < ApplicationSerializer
        attributes :type, :title, :color, :description, :url, :parent_name, :parent_color, :simple

        def type
          object["type"]
        end

        def title
          object["title"]
        end

        def color
          object["color"]
        end

        def description
          object["description"]
        end

        def include_description?
          object["description"].present?
        end

        def url
          object["url"]
        end

        def include_url?
          object["url"].present?
        end

        def parent_name
          object["parent_name"]
        end

        def include_parent_name?
          object["parent_name"].present?
        end

        def parent_color
          object["parent_color"]
        end

        def include_parent_color?
          object["parent_color"].present?
        end

        def include_simple?
          object["simple"].present?
        end
      end
    end
  end
end
