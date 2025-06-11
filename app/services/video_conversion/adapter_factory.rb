# frozen_string_literal: true
require_relative "aws_mediaconvert_adapter"

module VideoConversion
  class AdapterFactory
    def self.get_adapter(upload, options = {})
      adapter_type = options[:adapter_type] || SiteSetting.video_conversion_service

      case adapter_type
      when "aws_mediaconvert"
        AwsMediaConvertAdapter.new(upload, options)
      else
        raise ArgumentError, "Unknown video conversion service: #{adapter_type}"
      end
    end
  end
end
