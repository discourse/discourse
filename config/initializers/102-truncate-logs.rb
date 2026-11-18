# frozen_string_literal: true

require "truncate_logs_formatter"

if TruncateLogsFormatter.enabled?(Rails.env)
  def set_or_extend_truncate_logs_formatter(logger)
    if logger.formatter
      logger.formatter.extend(
        Module.new do
          def call(*args)
            truncate_logs_formatter.call(super(*args))
          end

          def truncate_logs_formatter
            @formatter ||=
              TruncateLogsFormatter.new(log_line_max_chars: GlobalSetting.log_line_max_chars)
          end
        end,
      )
    else
      logger.formatter =
        TruncateLogsFormatter.new(log_line_max_chars: GlobalSetting.log_line_max_chars)
    end
  end

  Rails.application.config.to_prepare do
    Rails.logger.broadcasts.each { |logger| set_or_extend_truncate_logs_formatter(logger) }
    if DiscourseLograge.enabled?
      set_or_extend_truncate_logs_formatter(Rails.configuration.lograge.logger)
    end
  end
end
