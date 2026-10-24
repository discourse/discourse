# frozen_string_literal: true

require "liquid"

class FormTemplate::OutputRenderer
  RENDER_SCORE_LIMIT = 200_000
  ASSIGN_SCORE_LIMIT = 1.megabyte

  def self.render(field_values, source)
    return FormTemplate::DefaultRenderer.render(field_values) if source.blank?

    template = Liquid::Template.parse(source)
    template.resource_limits.render_length_limit = SiteSetting.max_post_length * 4
    template.resource_limits.render_score_limit = RENDER_SCORE_LIMIT
    template.resource_limits.assign_score_limit = ASSIGN_SCORE_LIMIT
    template.render!({ "answers" => field_values.answers })
  end
end
