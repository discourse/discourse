# frozen_string_literal: true

# See https://github.com/Shopify/pitchfork/blob/18869d2f02549a54d7b2db6e0351e7fa71e95546/lib/pitchfork.rb#L120
# Pitchfork originally logs backtrace line by line with `exc.backtrace.each { |line| logger.error(line) }`.
# However, that means we get a separate logstash message for each backtrace which isn't what we want. The
# monkey patch here overrides Pitchfork's logging of error so that we log the error and backtrace in a
# single message.
module Pitchfork
  def self.log_error(logger, prefix, exc)
    message = exc.message
    message = message.dump if /[[:cntrl:]]/ =~ message
    logger.error "#{prefix}: #{message} (#{exc.class})\n#{exc.backtrace.join("\n")}"
  end
end
