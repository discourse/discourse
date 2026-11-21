# frozen_string_literal: true

module Migrations
  module Importer
    module Customizations
      module Export
        class SiteSettings
          def initialize(values, include_secrets:)
            @values = values
            @include_secrets = include_secrets
          end

          def call(item)
            name = item["name"]
            raise Error, "unknown site setting" unless ::SiteSetting.has_setting?(name)
            if Plan::SiteFacts.global_setting?(name)
              raise Error, "overridden by a global setting on this site"
            end

            entry = item.slice("name", "target", "note")
            row = ::SiteSetting.provider.find(name.to_sym)
            # Without a stored row the setting is at its default.
            return entry.merge("reset" => true) if item["reset"] || row.nil?

            if secret?(name)
              entry["secret"] = true
              entry["value"] = @include_secrets ? row.value : nil
            else
              entry["value"] = @values.site_setting(name, row.value)
            end
            entry
          end

          def secret?(name)
            ::SiteSetting.secret_settings.include?(name.to_sym) || Secrets.secret_name?(name)
          end
        end
      end
    end
  end
end
