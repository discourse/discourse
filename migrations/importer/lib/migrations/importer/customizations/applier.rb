# frozen_string_literal: true

module Migrations
  module Importer
    module Customizations
      # Applies the items of a bundle meant for one target. Every item compares
      # first and only writes what differs, so running it again after each test
      # migration is safe.
      class Applier
        def initialize(
          bundle_path:,
          target:,
          matcher:,
          dry_run: false,
          secrets: Secrets.new,
          output: $stdout
        )
          if Plan::APPLY_TARGETS.exclude?(target)
            raise Error, "target must be one of #{Plan::APPLY_TARGETS.join(", ")}"
          end

          @bundle_path = bundle_path
          @target = target
          @matcher = matcher
          @dry_run = dry_run
          @secrets = secrets
          @output = output
          @report = Report.new(output:)
        end

        # @return [Report]
        def run
          Bundle::Reader.open(@bundle_path) do |bundle|
            @output.puts "Dry run: nothing will be changed." if @dry_run
            setup(bundle)

            run_section("color_schemes") { |entry| @color_schemes.call(entry) }
            run_section("themes") { |entry| @themes.apply_code(entry) }
            run_section("themes", label: "theme settings") do |entry|
              @themes.apply_relations(entry)
            end
            run_section("site_settings") { |entry, last_try| @site_settings.call(entry, last_try:) }
            run_section("groups") { |entry| @groups.call(entry) }
            run_section("categories") { |entry| @categories.call(entry) }
            run_section("translation_overrides") { |entry| @translation_overrides.call(entry) }
          end

          @report.print_summary
          @report
        end

        private

        def setup(bundle)
          @items = bundle.manifest["items"]
          raise Error, "manifest has no items" unless @items.is_a?(Hash)

          lookup = Apply::Lookup.new(@matcher, dry_run: @dry_run)
          values = Apply::Values.new(Apply::Uploads.new(bundle, dry_run: @dry_run), lookup)

          @color_schemes = Apply::ColorSchemes.new(lookup, dry_run: @dry_run)
          @themes = Apply::Themes.new(bundle, values, lookup, dry_run: @dry_run)
          @site_settings = Apply::SiteSettings.new(values, @secrets, dry_run: @dry_run)
          @groups = Apply::Groups.new(values, @matcher, target: @target, dry_run: @dry_run)
          @categories = Apply::Categories.new(values, @matcher, target: @target, dry_run: @dry_run)
          @translation_overrides = Apply::TranslationOverrides.new(dry_run: @dry_run)
        end

        def run_section(section, label: section)
          entries = @items[section]
          return if entries.nil?
          raise Error, "manifest section #{section} must be a list" unless entries.is_a?(Array)

          retries = []
          entries.each do |entry|
            next unless entry.is_a?(Hash) && entry["target"] == @target

            apply_item(section, label, entry, last_try: false) { yield entry, false }
          rescue Apply::RetryLater
            retries << entry
          end

          retries.each do |entry|
            apply_item(section, label, entry, last_try: true) { yield entry, true }
          end
        end

        def apply_item(section, label, entry, last_try:)
          @report.item(label, Labels.for(section, entry)) do
            # A savepoint per item: a failed statement must not abort the
            # surrounding transaction, and an item is never half applied.
            ::ActiveRecord::Base.transaction(requires_new: true) { yield }
          rescue Apply::PendingDependency => e
            [:changed, e.message]
          end
        end
      end
    end
  end
end
