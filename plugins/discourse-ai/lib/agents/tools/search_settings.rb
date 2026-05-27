# frozen_string_literal: true

module DiscourseAi
  module Agents
    module Tools
      class SearchSettings < Tool
        INCLUDE_DESCRIPTIONS_MAX_LENGTH = 10
        MAX_RESULTS = 200

        def self.signature
          {
            name: name,
            description: "Will search through site settings and return top 20 results",
            parameters: [
              {
                name: "query",
                description:
                  "comma delimited list of settings to search for (e.g. 'setting_1,setting_2')",
                type: "string",
                required: true,
              },
            ],
          }
        end

        def self.name
          "search_settings"
        end

        def query
          parameters[:query].to_s
        end

        def all_settings
          @all_settings ||= SiteSetting.all_settings
        end

        def all_settings=(settings)
          # this is only used for testing
          @all_settings = settings
        end

        def invoke
          @last_num_results = 0

          terms = query.split(",").map(&:strip).map(&:downcase).reject(&:blank?)

          terms_regexes =
            terms.map do |term|
              regex_string = term.split(/[ _\.\|]/).map { |t| Regexp.escape(t) }.join(".*")
              Regexp.new(regex_string, Regexp::IGNORECASE)
            end

          found =
            all_settings.filter do |setting|
              name = setting[:setting].to_s.downcase
              description = setting[:description].to_s.downcase
              plugin = setting[:plugin].to_s.downcase

              search_string = "#{name} #{description} #{plugin}"

              terms_regexes.any? { |regex| search_string.match?(regex) }
            end

          if found.blank?
            {
              args: {
                query: query,
              },
              rows: [],
              instruction: "no settings matched #{query}, expand your search",
            }
          else
            include_descriptions = false

            if found.length > MAX_RESULTS
              found = found[0..MAX_RESULTS]
            elsif found.length < INCLUDE_DESCRIPTIONS_MAX_LENGTH
              include_descriptions = true
            end

            @last_num_results = found.length

            format_results(found, args: { query: query }) do |setting|
              result = { name: setting[:setting] }
              if include_descriptions
                result[:description] = setting[:description]
                result[:plugin] = setting[:plugin]
              end
              result
            end
          end
        end

        protected

        def description_args
          { count: @last_num_results || 0, query: parameters[:query].to_s }
        end
      end
    end
  end
end
