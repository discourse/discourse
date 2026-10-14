# frozen_string_literal: true

module Migrations
  module Importer
    module Customizations
      module Export
        class Groups
          def initialize(values, matcher)
            @values = values
            @matcher = matcher
          end

          def call(item)
            keys = item["match"].presence || { "name" => item["name"] }
            match = @matcher.resolve(:group, keys) { |id| ::Group.exists?(id:) }
            raise Error, "group not found" if match.nil?

            group = ::Group.find(match.id)
            {
              "name" => Matcher::Strategies::NaturalKey.group_name(group),
              "automatic" => group.automatic,
              "match" => @matcher.keys_for(:group, group),
              "attributes" =>
                Attributes.export(
                  group,
                  item["attributes"],
                  Plan::Rules::GROUP_ATTRIBUTES,
                  @values,
                ),
            }.merge(item.slice("target", "note"))
          end
        end
      end
    end
  end
end
