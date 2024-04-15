# frozen_string_literal: true

if Rails.env.production? || ENV["ENABLE_LOGS_TRUNCATION"] == "1"
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
    set_or_extend_truncate_logs_formatter(Rails.logger)

    if Rails.logger.respond_to? :chained
      Rails.logger.chained.each { |logger| set_or_extend_truncate_logs_formatter(logger) }
    end
  end
end
