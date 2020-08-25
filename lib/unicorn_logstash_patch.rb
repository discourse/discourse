# frozen_string_literal: true

# See https://github.com/defunkt/unicorn/commit/5f478f5a9a58f72c0a844258b8ee614bf24ea9f7
# Unicorn originally logs backtrace line by line with `exc.backtrace.each { |line| logger.error(line) }`.
# However, that means we get a separate logstash message for each backtrace which isn't what we want. The
# monkey patch here overrides Unicorn's logging of error so that we log the error and backtrace in a
# single message.
module Unicorn
  def self.log_error(logger, prefix, exc)
    message = exc.message
    message = message.dump if /[[:cntrl:]]/ =~ message
    logger.error "#{prefix}: #{message} (#{exc.class})\n#{exc.backtrace.join("\n")}"
  end
end
