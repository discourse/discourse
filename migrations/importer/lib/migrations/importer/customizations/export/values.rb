# frozen_string_literal: true

module Migrations
  module Importer
    module Customizations
      module Export
        # Turns stored ids into portable references: names, matcher keys and
        # upload references.
        class Values
          def initialize(uploads, matcher)
            @uploads = uploads
            @matcher = matcher
          end

          def site_setting(name, raw)
            if SettingReferences::THEME_SETTINGS.include?(name)
              return raw.blank? ? raw : { "theme" => theme_ref(::Theme.find_by(id: raw.to_i)) }
            end
            if SettingReferences::COLOR_SCHEME_SETTINGS.include?(name)
              scheme = ::ColorScheme.find_by(id: raw.to_i) if raw.to_i > 0
              return scheme ? { "color_scheme" => color_scheme_ref(scheme) } : raw
            end

            type = ::SiteSetting.type_supervisor.get_type(name.to_sym)
            return raw if raw.blank? && type != :objects

            case type
            when :upload
              upload(raw)
            when :uploaded_image_list
              { "uploads" => ids(raw).map { |id| upload(id) } }
            when :group, :group_list
              { "groups" => ids(raw).map { |id| group_name(id) } }
            when :category, :category_list
              { "categories" => ids(raw).map { |id| category_keys(id) } }
            when :objects
              schema = ::SiteSetting.type_supervisor.type_hash(name.to_sym)[:schema]
              { "objects" => objects(raw.presence && JSON.parse(raw), schema) }
            when :topic, :username
              raise Error, "references a #{type}; set it by hand on the migrated site"
            else
              raw
            end
          end

          def upload(id)
            return if id.blank?
            @uploads.ref(id.to_i)
          end

          def objects(objects, schema)
            ObjectsUploads.transform(objects || [], schema) do |value|
              upload_id =
                if value.is_a?(Integer)
                  value
                elsif value.is_a?(String) && value.present?
                  ::Upload.get_from_url(value)&.id
                end
              upload_id ? upload(upload_id) : value
            end
          end

          def theme_ref(theme)
            return if theme.nil?

            ref = { "name" => theme.name }
            ref["system_id"] = theme.id if theme.id < 0
            ref
          end

          def color_scheme_ref(scheme)
            return if scheme.nil?

            ref = { "name" => scheme.name }
            ref["theme"] = theme_ref(scheme.theme) if scheme.theme_id
            ref
          end

          def group_name(id)
            group = ::Group.find_by(id:)
            raise Error, "group #{id} does not exist" if group.nil?
            Matcher::Strategies::NaturalKey.group_name(group)
          end

          def category_keys(id)
            category = ::Category.find_by(id:)
            raise Error, "category #{id} does not exist" if category.nil?
            @matcher.keys_for(:category, category)
          end

          private

          def ids(raw)
            raw.to_s.split("|").reject(&:blank?)
          end
        end
      end
    end
  end
end
