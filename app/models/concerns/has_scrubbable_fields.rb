# frozen_string_literal: true

module HasScrubbableFields
  extend ActiveSupport::Concern

  def scrub_field(field, tags = [], attributes = [])
    if field
      scrubber = Rails::Html::PermitScrubber.new
      scrubber.attributes = attributes
      scrubber.tags = tags
      html_fragment = Loofah.fragment(field)
      html_fragment.scrub!(scrubber)
      return html_fragment.to_s
    end
    field
  end
end
