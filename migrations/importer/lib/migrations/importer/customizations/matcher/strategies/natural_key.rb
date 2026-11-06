# frozen_string_literal: true

module Migrations
  module Importer
    module Customizations
      class Matcher
        module Strategies
          # Group name (automatic groups by their built-in key), category slug
          # path (e.g. `parent-slug/child-slug`), username and tag name. Topics
          # have no natural key; a post's `post_number` only identifies it
          # together with its topic, which the caller resolves.
          class NaturalKey
            def name
              "natural_key"
            end

            def keys_for(kind, record)
              case kind
              when :category
                { "slug_path" => self.class.slug_path(record) }
              when :group
                { "name" => self.class.group_name(record) }
              when :topic
                {}
              when :post
                { "post_number" => record.post_number }
              when :user
                { "username" => record.username }
              when :tag
                { "name" => record.name }
              else
                raise ArgumentError, "unknown kind: #{kind}"
              end
            end

            def find_id(kind, keys)
              case kind
              when :category
                return if keys["slug_path"].blank?
                ::Category.find_by_slug_path(keys["slug_path"].split("/"))&.id
              when :group
                self.class.group_id_by_name(keys["name"])
              when :user
                return if keys["username"].blank?
                ::User.find_by_username(keys["username"])&.id
              when :tag
                return if keys["name"].blank?
                ::Tag.find_by_name(keys["name"])&.id
              when :topic, :post
                nil
              else
                raise ArgumentError, "unknown kind: #{kind}"
              end
            end

            def self.slug_path(category)
              slugs = []
              seen = Set.new
              current = category
              while current && seen.add?(current.id)
                slugs.unshift(current.slug)
                current = current.parent_category
              end
              slugs.join("/")
            end

            # Automatic group names can be localized, so they travel by key.
            def self.group_name(group)
              (group.automatic && ::Group::AUTO_GROUP_IDS[group.id]&.to_s) || group.name
            end

            def self.group_id_by_name(name)
              return if name.blank?
              return ::Group::AUTO_GROUPS[name.to_sym] if ::Group::AUTO_GROUPS.key?(name.to_sym)

              ::Group.where("LOWER(name) = ?", name.downcase).pick(:id)
            end
          end
        end
      end
    end
  end
end
