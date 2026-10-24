# frozen_string_literal: true

require "liquid"

class FormTemplate::OutputRenderer
  TAGS = %w[if unless for case assign capture comment raw break continue].freeze
  ENVIRONMENT =
    Liquid::Environment.build(
      tags: Liquid::Environment.default.tags.slice(*TAGS),
      error_mode: :strict,
    )

  def self.parse(source)
    template = Liquid::Template.parse(source, environment: ENVIRONMENT)
    # Rendering limits do not cover allocations inside filters or range expansion.
    Liquid::ParseTreeVisitor
      .for(template.root)
      .add_callback_for(Range, Liquid::RangeLookup) do
        raise Liquid::SyntaxError, "Numeric ranges are not supported"
      end
      .add_callback_for(Liquid::Variable) do |variable|
        raise Liquid::SyntaxError, "Filters are not supported" if variable.filters.any?
      end
      .visit
    template
  end

  def self.render(field_values, source)
    return FormTemplate::DefaultRenderer.render(field_values) if source.blank?

    template = parse(source)
    template.resource_limits.render_length_limit = SiteSetting.max_post_length * 4
    template.resource_limits.render_score_limit = 10_000
    template.resource_limits.assign_score_limit = 10_000
    template.render!({ "answers" => field_values.answers }, strict_filters: true)
  end
end
