# frozen_string_literal: true

require "discourse/safe_exec"
require "image_processing/instrumentation"

module ImageProcessing
  class Command
    OPERATIONS = %i[
      upload_svg_dimensions
      upload_dominant_color
      upload_quality_probe
      upload_format_conversion
      upload_auto_orient
      upload_animation_probe
      optimized_image_resize
      optimized_image_crop
      optimized_image_downsize
      topic_og_asset_render
      topic_og_render
      letter_avatar_render
      letter_avatar_version
      letter_avatar_font_list
    ].freeze
    private_constant :OPERATIONS

    def self.capture(*command, operation:, **options)
      if !OPERATIONS.include?(operation)
        raise ArgumentError, "unknown image-processing operation: #{operation.inspect}"
      end

      Discourse::SafeExec.capture(*command, **options) do |result|
        Instrumentation.record(operation:, result:)
      rescue StandardError
        nil
      end
    end
  end
end
