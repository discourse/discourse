# frozen_string_literal: true

require "time"

module Migrations
  module Importer
    module Customizations
      # Reads the current values of every non-skip plan item from the connected
      # site and writes them into a bundle.
      class Exporter
        def initialize(
          plan:,
          output_path:,
          matcher:,
          upload_base_url: nil,
          include_secrets: true,
          output: $stdout
        )
          @plan = plan
          @output_path = output_path
          @matcher = matcher
          @upload_base_url = upload_base_url
          @include_secrets = include_secrets
          @output = output
          @report = Report.new(output:)
        end

        # @return [Report]
        def run
          Bundle::Writer.open do |writer|
            uploads = Export::Uploads.new(writer, base_url: @upload_base_url)
            values = Export::Values.new(uploads, @matcher)
            handlers = {
              "site_settings" =>
                Export::SiteSettings.new(values, include_secrets: @include_secrets),
              "themes" => Export::Themes.new(writer, values, output: @output),
              "color_schemes" => Export::ColorSchemes.new(values),
              "groups" => Export::Groups.new(values, @matcher),
              "categories" => Export::Categories.new(values, @matcher),
              "translation_overrides" => Export::TranslationOverrides.new,
              "permalinks" => Export::Permalinks.new(@matcher),
            }

            items =
              Plan::SECTIONS.to_h do |section|
                entries = []
                @plan
                  .exportable_items(section)
                  .each do |item|
                    @report.item(section, Labels.for(section, item)) do
                      entries << handlers.fetch(section).call(item)
                      :exported
                    end
                  end
                [section, entries]
              end

            writer.write(@output_path, manifest(items))
          end

          @report.print_summary
          @output.puts "Bundle written to #{@output_path}"
          if @include_secrets
            @output.puts "WARNING: the bundle contains secret values. Handle it like a password.".red
          end
          @report
        end

        private

        def manifest(items)
          {
            "format_version" => Bundle::FORMAT_VERSION,
            "exported_at" => Time.now.utc.iso8601,
            "source" => {
              "base_url" => ::Discourse.base_url,
              "discourse_version" => ::Discourse::VERSION::STRING,
            },
            "secrets_included" => @include_secrets,
            "items" => items,
          }
        end
      end
    end
  end
end
