begin
  STDOUT.sync = true
  def Rails.heroku_stdout_logger
    logger = Logger.new(STDOUT)
    logger.level = Logger.const_get(([ENV['LOG_LEVEL'].to_s.upcase, "INFO"] & %w[DEBUG INFO WARN ERROR FATAL UNKNOWN]).compact.first)
    logger
  end
  Rails.logger = Rails.application.config.logger = Rails.heroku_stdout_logger
rescue Exception => ex
  puts "WARNING: Exception during rails_log_stdout init: #{ex.message}"
end