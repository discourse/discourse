# frozen_string_literal: true

module Migrations
  module Importer
    module Customizations
      module Apply
        class Categories
          def initialize(values, matcher, target:, dry_run:)
            @values = values
            @matcher = matcher
            @target = target
            @dry_run = dry_run
          end

          def call(entry)
            keys = entry["match"] || {}
            match = @matcher.resolve(:category, keys) { |id| ::Category.exists?(id:) }
            desired = Attributes.desired(entry, Plan::Rules::CATEGORY_ATTRIBUTES, @values)
            permissions = permissions(entry)

            return create(entry, keys, desired, permissions) if match.nil?

            category = ::Category.find(match.id)
            differences = Attributes.differences(category, desired)
            permissions = nil if permissions && same_permissions?(category, permissions)
            matched = "matched by #{match.strategy}"
            return :unchanged, matched if differences.empty? && permissions.nil?

            unless @dry_run
              category.assign_attributes(differences)
              category.set_permissions(permissions) if permissions
              category.save!
            end
            [:changed, matched]
          end

          private

          # @return [Hash{Integer => Integer}, nil] group id => permission type
          def permissions(entry)
            list = (entry["attributes"] || {})[Plan::Rules::CATEGORY_PERMISSIONS]
            return if list.nil?
            raise Error, "permissions must be a list" unless list.is_a?(Array)

            list.to_h do |permission|
              name = permission["group"].to_s
              group_id = Matcher::Strategies::NaturalKey.group_id_by_name(name)
              if group_id.nil?
                raise PendingDependency, "group '#{name}' does not exist yet" if @dry_run
                raise Error, "group '#{name}' does not exist"
              end
              [group_id, Integer(permission["permission_type"])]
            end
          end

          def same_permissions?(category, permissions)
            read_restricted, mapped = ::Category.resolve_permissions(permissions)
            current = category.category_groups.pluck(:group_id, :permission_type).to_set
            category.read_restricted == read_restricted && current == mapped.to_set
          end

          def create(entry, keys, desired, permissions)
            if @target == "import"
              raise SkipItem, "no matching category found (tried #{keys.keys.join(", ")})"
            end

            slugs = keys["slug_path"].to_s.split("/")
            raise Error, "slug_path is needed to create the category" if slugs.empty?

            parent_id = nil
            if slugs.size > 1
              parent = ::Category.find_by_slug_path(slugs[0..-2])
              raise Error, "parent category #{slugs[0..-2].join("/")} does not exist" if parent.nil?
              parent_id = parent.id
            end
            return :changed, "would be created" if @dry_run

            category =
              ::Category.new(
                name: entry["name"].presence || slugs.last,
                slug: slugs.last,
                parent_category_id: parent_id,
                user: ::Discourse.system_user,
              )
            category.assign_attributes(desired)
            category.set_permissions(permissions) if permissions
            category.save!
            [:changed, "created"]
          end
        end
      end
    end
  end
end
