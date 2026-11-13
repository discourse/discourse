# frozen_string_literal: true

module Migrations
  module Importer
    module Customizations
      module Export
        class Categories
          def initialize(values, matcher)
            @values = values
            @matcher = matcher
          end

          def call(item)
            match = @matcher.resolve(:category, item["match"]) { |id| ::Category.exists?(id:) }
            raise Error, "category not found" if match.nil?

            category = ::Category.find(match.id)
            attributes =
              Attributes.export(
                category,
                item["attributes"],
                Plan::Rules::CATEGORY_ATTRIBUTES,
                @values,
              )
            if Array(item["attributes"]).include?(Plan::Rules::CATEGORY_PERMISSIONS)
              attributes[Plan::Rules::CATEGORY_PERMISSIONS] = permissions(category)
            end

            {
              "name" => category.name,
              "slug" => category.slug,
              "match" => @matcher.keys_for(:category, category),
              "attributes" => attributes,
            }.merge(item.slice("target", "note"))
          end

          private

          # A public category has no category_groups rows at all.
          def permissions(category)
            if !category.read_restricted && category.category_groups.empty?
              return [
                {
                  "group" => @values.group_name(::Group::AUTO_GROUPS[:everyone]),
                  "permission_type" => ::CategoryGroup.permission_types[:full],
                },
              ]
            end

            category
              .category_groups
              .order(:group_id)
              .map do |category_group|
                {
                  "group" => @values.group_name(category_group.group_id),
                  "permission_type" => category_group.permission_type,
                }
              end
          end
        end
      end
    end
  end
end
