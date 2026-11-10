# frozen_string_literal: true

module DiscourseAi
  module Agents
    module AppearanceAuthoring
      # Turns a request such as "rounder corners and a soft shadow on topic
      # rows" into typed theme styles (see AppearanceStyles::Policy) with an
      # LLM. The model answers in a fixed JSON shape and never writes CSS.
      # Every answer is checked by the policy; when it fails, the errors go
      # back to the model to fix, a few times at most. Only styles that pass
      # are returned, so what an administrator approves is what was checked.
      class StyleAuthor
        MAX_ATTEMPTS = 3
        MAX_REQUEST_LENGTH = 2000

        Result = Data.define(:styles, :changes, :unsupported, :attempts)
        Failure = Data.define(:errors, :attempts)

        # max_attempts and execution_context are for evals.
        def initialize(
          llm:,
          user:,
          feature_name:,
          max_attempts: MAX_ATTEMPTS,
          execution_context: nil
        )
          @llm = llm
          @user = user
          @feature_name = feature_name
          @max_attempts = max_attempts
          @execution_context = execution_context
        end

        # palettes: the light and dark colors the styles will be shown with,
        # as { light: { "primary" => "222222", ... }, dark: { ... } }.
        # current_styles: the styles of the theme being edited, if any; the
        # answer replaces them as a whole.
        # Returns a Result, or a Failure with the last errors.
        def call(request, palettes:, current_styles: nil)
          prompt = build_prompt(request.to_s.truncate(MAX_REQUEST_LENGTH), palettes, current_styles)
          errors = []

          @max_attempts.times do |attempt|
            prompt.push(type: :user, content: repair_message(errors)) if attempt > 0

            answer = ask(prompt)
            if answer.nil?
              return Failure.new(errors: ["The model gave no answer."], attempts: attempt + 1)
            end
            prompt.push(type: :model, content: JSON.generate(answer))

            styles = typed_styles(answer)
            unsupported = Array.wrap(answer["unsupported"]).map(&:to_s).compact_blank
            if styles.values.all?(&:blank?) && unsupported.empty?
              return Failure.new(errors: ["The model gave no styles."], attempts: attempt + 1)
            end

            result = AppearanceStyles::Policy.call(styles, palettes:)
            if result.valid?
              return(
                Result.new(
                  styles: styles.compact_blank,
                  changes: result.changes,
                  unsupported:,
                  attempts: attempt + 1,
                )
              )
            end
            errors = result.errors
          end

          Failure.new(errors:, attempts: @max_attempts)
        end

        private

        def ask(prompt)
          structured = nil
          response =
            @llm.generate(
              prompt,
              user: @user,
              feature_name: @feature_name,
              response_format:,
              execution_context: @execution_context,
            ) do |partial|
              structured = partial if partial.is_a?(DiscourseAi::Completions::StructuredOutput)
            end

          answer =
            JSON.parse(DiscourseAi::Completions::Llm.text_from_response(structured || response))
          answer if answer.is_a?(Hash)
        rescue JSON::ParserError, DiscourseAi::Completions::Endpoints::Base::CompletionFailed
          nil
        end

        # The schema uses lists of name and value pairs, because strict JSON
        # schemas can't describe objects with free-form keys.
        def typed_styles(answer)
          variables =
            Array
              .wrap(answer["variables"])
              .select { |variable| variable.is_a?(Hash) }
              .to_h { |variable| [variable["name"].to_s, variable["value"].to_s] }

          rules =
            Array
              .wrap(answer["rules"])
              .select { |rule| rule.is_a?(Hash) }
              .map do |rule|
                {
                  "area" => rule["area"].to_s,
                  "state" => rule["state"].to_s.presence,
                  "media" => rule["media"].to_s.presence,
                  "page" => rule["page"].to_s.presence,
                  "declarations" =>
                    Array
                      .wrap(rule["declarations"])
                      .select { |declaration| declaration.is_a?(Hash) }
                      .to_h do |declaration|
                        [declaration["property"].to_s, declaration["value"].to_s]
                      end,
                }.compact
              end

          { "variables" => variables, "rules" => rules }
        end

        def build_prompt(request, palettes, current_styles)
          request = <<~TEXT if current_styles.present?
              The theme already has these styles:
              #{JSON.generate(current_styles)}

              Change them as asked below, and answer with the whole set, including the styles to keep.

              #{request}
            TEXT

          DiscourseAi::Completions::Prompt.new(
            system_prompt(palettes),
            messages: [{ type: :user, content: request }],
          )
        end

        CONTRAST_ADVICE = <<~TEXT
          For text that isn't readable: mid-tone backgrounds such as brand blues and oranges often can't carry white or dark text. Make the background darker or lighter by mixing it with a palette color, such as color-mix(in srgb, var(--tertiary) 70%, var(--primary)), or give explicit shades with light-dark(#light, #dark), and set a color that contrasts with every color of a gradient.
        TEXT

        def repair_message(errors)
          advice = CONTRAST_ADVICE if errors.any? { |error| error.include?("text on background") }
          <<~TEXT
            Those styles were rejected:
            #{errors.map { |error| "- #{error}" }.join("\n")}
            #{advice}
            Answer again with the whole set of styles, fixed. Drop anything you can't express within the rules and list it under unsupported.
          TEXT
        end

        def system_prompt(palettes)
          <<~PROMPT
            You write the styles for a Discourse forum theme from an administrator's request. You never write CSS. You answer with:

            - variables: overrides of the design variables listed below, as name and value.
            - rules: changes to a named area of the forum, as area, optional state, media and page, and declarations of property and value. The server writes the selectors.
            - unsupported: short descriptions of anything asked for that these styles can't do, such as adding links, menus, images, fonts or changing the layout.

            Prefer a variable whenever one does the job; use a rule only for what no variable reaches. Keep changes to what was asked for.

            Values:
            - Colors must follow the palette, so dark mode keeps working: var(--primary), var(--tertiary-low) and the other palette variables, rgba(var(--primary-rgb), 0.1), color-mix(in srgb, var(--tertiary) 20%, var(--secondary)), or light-dark(#light, #dark) for a raw color. A raw hex outside light-dark() is rejected.
            - var() may only reference palette or design variables, without fallbacks.
            - Lengths use px, rem, em or %. No url(), no quotes, no !important, no comments.
            - Fonts are chosen elsewhere; font-family only takes var(--font-family) or var(--heading-font-family).
            - Text must stay readable on its background in light and dark mode (4.5:1).

            Rule options:
            - state: hover, odd or even, only where the area lists it. media: mobile or desktop. page: topic, lists or categories, only when the administrator asks for a change on particular pages. Use an empty string when not needed.
            - When you give an area a background, make sure its text stays readable; set color too if needed.
            - display only allows none, and only on areas marked hideable. width and height only on areas marked sizeable.
            - Allowed properties: #{AppearanceStyles::Policy::PROPERTY_SPECS.keys.join(", ")}.

            Palette colors (light / dark): #{palette_summary(palettes)}

            Areas (key: description [options]):
            #{area_lines}

            Design variables (name: type, bounds, default):
            #{variable_lines}
          PROMPT
        end

        def palette_summary(palettes)
          light = palettes[:light] || {}
          dark = palettes[:dark] || {}
          AppearanceStyles::PaletteColors::BASE_NAMES
            .map { |name| "#{name} ##{light[name]} / ##{dark[name]}" }
            .join(", ")
        end

        def area_lines
          AppearanceStyles::AreaCatalog
            .instance
            .all
            .map do |area|
              options = [
                *area.states,
                ("hideable" if area.hideable),
                ("sizeable" if area.sizeable),
              ].compact
              "- #{area.key}: #{area.label}#{" [#{options.join(", ")}]" if options.any?}"
            end
            .join("\n")
        end

        def variable_lines
          AppearanceStyles::VariableRegistry
            .instance
            .allowed
            .map do |variable|
              bounds =
                if variable.min_px
                  "#{variable.min_px}px to #{variable.max_px}px"
                elsif variable.keywords
                  variable.keywords.join("|")
                end
              # some compiled defaults name build-time helper variables
              default = variable.default if !variable.default.to_s.include?("csstools")
              "- #{variable.name}: #{[variable.type, bounds, default].compact.join(", ")}"
            end
            .join("\n")
        end

        def response_format
          name_value = ->(name, value) do
            {
              type: "object",
              additionalProperties: false,
              required: [name, value],
              properties: {
                name => {
                  type: "string",
                },
                value => {
                  type: "string",
                },
              },
            }
          end

          rule = {
            type: "object",
            additionalProperties: false,
            required: %w[area state media page declarations],
            properties: {
              area: {
                type: "string",
              },
              state: {
                type: "string",
              },
              media: {
                type: "string",
              },
              page: {
                type: "string",
              },
              declarations: {
                type: "array",
                items: name_value.call("property", "value"),
              },
            },
          }

          {
            type: "json_schema",
            json_schema: {
              name: "theme_styles",
              strict: true,
              schema: {
                type: "object",
                additionalProperties: false,
                required: %w[variables rules unsupported],
                properties: {
                  variables: {
                    type: "array",
                    items: name_value.call("name", "value"),
                  },
                  rules: {
                    type: "array",
                    items: rule,
                  },
                  unsupported: {
                    type: "array",
                    items: {
                      type: "string",
                    },
                  },
                },
              },
            },
          }
        end
      end
    end
  end
end
