# frozen_string_literal: true

require "liquid"

class FormTemplate::OutputRenderer
  RENDER_SCORE_LIMIT = 200_000
  ASSIGN_SCORE_LIMIT = 1.megabyte

  class Context < Liquid::Context
    def evaluate(object)
      value = super
      # Loops materialize ranges before render accounting runs, and answers can set their bounds.
      resource_limits.increment_render_score(value.size) if value.is_a?(Range)
      value
    end
  end

  def self.render(field_values, source)
    return FormTemplate::DefaultRenderer.render(field_values) if source.blank?

    template = Liquid::Template.parse(source)
    template.resource_limits.render_length_limit = SiteSetting.max_post_length * 4
    template.resource_limits.render_score_limit = RENDER_SCORE_LIMIT
    template.resource_limits.assign_score_limit = ASSIGN_SCORE_LIMIT
    context =
      Context.build(
        environments: {
          "answers" => field_values.template_answers,
        },
        resource_limits: template.resource_limits,
        rethrow_errors: true,
      )
    template.render!(context)
  rescue Liquid::Error
    raise
  rescue StandardError => e
    raise Liquid::InternalError, e.message
  end
end
