# frozen_string_literal: true

require_relative "base"

module DiscourseAi
  module Evals
    module Runners
      # Runs the Admin Assistant's style author on a request and reports what
      # came back as JSON, for cases to match with expected_output_regex:
      #
      #   {"result":"styles","attempts":1,"variables":{...},
      #    "rules":[{"area":"header","state":null,"page":null,"properties":{...}}],
      #    "unsupported":[...],"errors":[]}
      #
      # result is "styles" when checked styles came back, "unsupported" when
      # the model said none of the request can be done with styles, and
      # "failed" when it couldn't produce styles that pass the checks.
      #
      # Case args:
      # - input: the administrator's request
      # - current_styles: the styles of a theme being edited (optional)
      # - brand_color: build the palettes from this brand color instead of
      #   using core's (optional)
      #
      # APPEARANCE_STYLES_MAX_ATTEMPTS=1 measures how often the first answer
      # passes, without the chance to fix it.
      class AppearanceStyles < Base
        FEATURE = "custom:appearance_styles"
        FEATURE_NAME = "evals/appearance_styles"

        def self.can_handle?(full_feature_name)
          full_feature_name == FEATURE
        end

        def run(eval_case, llm, execution_context:)
          args = eval_case.args
          max_attempts =
            ENV["APPEARANCE_STYLES_MAX_ATTEMPTS"].presence&.to_i ||
              DiscourseAi::Agents::AppearanceAuthoring::StyleAuthor::MAX_ATTEMPTS
          started_at = Time.zone.now
          started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

          result =
            DiscourseAi::Agents::AppearanceAuthoring::StyleAuthor.new(
              llm: llm.to_llm,
              user: Discourse.system_user,
              feature_name: FEATURE_NAME,
              max_attempts:,
              execution_context:,
            ).call(
              args[:input],
              palettes: palettes(args[:brand_color]),
              current_styles: args[:current_styles]&.deep_stringify_keys,
            )

          seconds = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).round(1)
          wrap_result(JSON.generate(summary(result)), usage(started_at).merge(seconds:))
        end

        private

        def palettes(brand_color)
          if brand_color.present?
            built =
              ColorSchemes::Action::BuildFromBrand.call(
                brand: DiscourseAi::Agents::AppearanceAuthoring.parse_hex(brand_color),
              )
            return { light: built.light, dark: built.dark }
          end

          {
            light:
              DiscourseAi::Agents::AppearanceAuthoring.complete_palette(ColorScheme.base_colors),
            dark:
              DiscourseAi::Agents::AppearanceAuthoring.complete_palette(
                ColorScheme::BUILT_IN_SCHEMES[:Dark],
              ),
          }
        end

        def summary(result)
          if result.is_a?(DiscourseAi::Agents::AppearanceAuthoring::StyleAuthor::Failure)
            return { result: "failed", attempts: result.attempts, errors: result.errors }
          end

          styles = result.styles
          {
            result: styles.present? ? "styles" : "unsupported",
            attempts: result.attempts,
            variables: styles["variables"] || {},
            rules:
              (styles["rules"] || []).map do |rule|
                {
                  area: rule["area"],
                  state: rule["state"],
                  page: rule["page"],
                  media: rule["media"],
                  properties: rule["declarations"],
                }
              end,
            unsupported: result.unsupported,
            errors: [],
          }
        end

        def usage(started_at)
          logs = AiApiAuditLog.where(feature_name: FEATURE_NAME, created_at: started_at..)
          { request_tokens: logs.sum(:request_tokens), response_tokens: logs.sum(:response_tokens) }
        end
      end
    end
  end
end
