# frozen_string_literal: true

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
