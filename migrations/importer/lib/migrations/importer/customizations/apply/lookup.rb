# frozen_string_literal: true

module Migrations
  module Importer
    module Customizations
      module Apply
        # Resolves portable references from the manifest to records on the
        # target site.
        class Lookup
          def initialize(matcher, dry_run:)
            @matcher = matcher
            @dry_run = dry_run
          end

          # @return [Theme]
          def theme(ref)
            raise Error, "invalid theme reference: #{ref.inspect}" unless ref.is_a?(Hash)

            if ref["system_id"]
              theme = ::Theme.find_by(id: ref["system_id"].to_i)
              raise Error, "system theme #{ref["system_id"]} does not exist" if theme.nil?
              return theme
            end

            themes = ::Theme.where(name: ref["name"].to_s).to_a
            missing!("theme '#{ref["name"]}'") if themes.empty?
            if themes.size > 1
              raise Error,
                    "#{themes.size} themes are named '#{ref["name"]}'; rename them to tell them apart"
            end
            themes.first
          end

          # @return [ColorScheme, nil] nil when no palette has that name
          def color_scheme(ref)
            raise Error, "invalid color palette reference: #{ref.inspect}" unless ref.is_a?(Hash)

            schemes = ::ColorScheme.where(name: ref["name"].to_s).to_a
            owner = ref["theme"]
            if owner
              owned = schemes.select { |s| s.theme && theme_matches?(s.theme, owner) }
              return owned.first if owned.size == 1
            end

            standalone = schemes.select { |s| s.theme_id.nil? }
            candidates = standalone.any? ? standalone : schemes
            if candidates.size > 1
              raise Error,
                    "#{candidates.size} color palettes are named '#{ref["name"]}'; rename them to tell them apart"
            end
            candidates.first
          end

          def color_scheme!(ref)
            color_scheme(ref) || missing!("color palette '#{ref["name"]}'")
          end

          def group_id(name)
            id = Matcher::Strategies::NaturalKey.group_id_by_name(name.to_s)
            id || missing!("group '#{name}'")
          end

          def category_id(keys)
            match = @matcher.resolve(:category, keys) { |id| ::Category.exists?(id:) }
            match&.id || missing!("category #{keys.inspect}")
          end

          private

          def theme_matches?(theme, ref)
            ref["system_id"] ? theme.id == ref["system_id"].to_i : theme.name == ref["name"]
          end

          # In a dry run the missing record may be one this run would create.
          def missing!(what)
            raise PendingDependency, "#{what} does not exist yet" if @dry_run
            raise Error, "#{what} does not exist"
          end
        end
      end
    end
  end
end
