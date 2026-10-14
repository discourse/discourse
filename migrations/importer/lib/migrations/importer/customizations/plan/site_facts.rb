# frozen_string_literal: true

module Migrations
  module Importer
    module Customizations
      class Plan
        # What the plan builder needs to know about the connected site.
        class SiteFacts
          # Covers values set in this process's environment (DISCOURSE_<NAME>) and
          # settings that global config can always override.
          def self.global_setting?(name)
            name = name.to_sym
            ::SiteSetting.shadowed_settings.include?(name) || ::GlobalSetting.respond_to?(name)
          end

          MODELS = { "groups" => "Group", "categories" => "Category" }.freeze

          def initialize(matcher)
            @matcher = matcher
          end

          def site_setting(name)
            return unless ::SiteSetting.has_setting?(name)

            symbol = name.to_sym
            {
              type: ::SiteSetting.type_supervisor.get_type(symbol),
              hidden: ::SiteSetting.hidden_settings.include?(symbol),
              secret: ::SiteSetting.secret_settings.include?(symbol),
              themeable: ::SiteSetting.themeable[symbol].present?,
              global: SiteFacts.global_setting?(symbol),
            }
          end

          def automatic_group_id?(id)
            ::Group::AUTO_GROUP_IDS.key?(id)
          end

          def theme(id)
            theme = ::Theme.find_by(id:)
            return if theme.nil?

            { name: theme.name, system: theme.id < 0, git: theme.remote_theme&.remote_url.present? }
          end

          def color_scheme(id)
            scheme = ::ColorScheme.find_by(id:)
            return if scheme.nil?

            { name: scheme.name, theme_id: scheme.theme_id }
          end

          def group(id)
            group = ::Group.find_by(id:)
            return if group.nil?

            match = @matcher.keys_for(:group, group)
            {
              name: Matcher::Strategies::NaturalKey.group_name(group),
              automatic: group.automatic,
              imported: imported?(match),
              match:,
            }
          end

          def category(id)
            category = ::Category.find_by(id:)
            return if category.nil?

            match = @matcher.keys_for(:category, category)
            { name: category.name, imported: imported?(match), match: }
          end

          def default_value?(table, column, value)
            model = MODELS.fetch(table).constantize
            cast = model.type_for_attribute(column).cast(value)
            default = model.column_defaults[column]
            cast == default || Rules.blank_equal?(cast, default)
          end

          private

          def imported?(match)
            match.key?("original_id") || match.key?("import_id")
          end
        end
      end
    end
  end
end
