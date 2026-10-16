# frozen_string_literal: true

module Migrations
  module Importer
    module Customizations
      module Apply
        class SiteSettings
          def initialize(values, secrets, dry_run:)
            @values = values
            @secrets = secrets
            @dry_run = dry_run
          end

          # Settings whose validator reads other settings (e.g. a login provider's
          # credentials) can fail until those are written, so they are retried
          # after the rest. A dry run writes nothing and can't validate them.
          def call(entry, last_try: true)
            name = entry["name"].to_s
            raise SkipItem, "unknown setting on this site" unless ::SiteSetting.has_setting?(name)
            if Plan::SiteFacts.global_setting?(name)
              raise SkipItem, "overridden by a global setting on this site"
            end
            if ::SiteSetting.themeable[name.to_sym]
              raise SkipItem, "themeable; set it as a theme site setting"
            end

            return reset(name) if entry["reset"]

            value =
              if entry["secret"] && entry["value"].nil?
                @secrets.fetch(name) ||
                  raise(SkipItem, "secret not provided (set #{Secrets.env_name(name)})")
              else
                @values.site_setting(name, entry["value"])
              end

            new_value =
              begin
                db_value(name, value)
              rescue ::Discourse::InvalidParameters => e
                raise RetryLater unless last_try
                raise PendingDependency, "not validated in a dry run: #{e.message}" if @dry_run
                raise
              end
            return :unchanged if new_value == current_db_value(name)

            ::SiteSetting.set_and_log(name, value, ::Discourse.system_user) unless @dry_run
            :changed
          end

          private

          def reset(name)
            return :unchanged if ::SiteSetting.provider.find(name.to_sym).nil?

            ::SiteSetting.remove_override!(name.to_sym) unless @dry_run
            :changed
          end

          def db_value(name, value)
            ::SiteSetting.type_supervisor.to_db_value(name.to_sym, value).first.to_s
          end

          def current_db_value(name)
            row = ::SiteSetting.provider.find(name.to_sym)
            return row.value.to_s if row

            default = ::SiteSetting.defaults.get(name.to_sym, ::SiteSetting.default_locale)
            begin
              db_value(name, default)
            rescue StandardError
              default.to_s
            end
          end
        end
      end
    end
  end
end
