# frozen_string_literal: true

require "playwright"

# Temporary until the client can avoid building frames that the protocol drops.
# Keep the regular caller lookup, API name, wall time, title, and first frame.
module SystemPlaywrightRpcMetadata
  private

  def build_metadata_payload_from(api_name, stacks)
    # Connection sends only the first caller as the operation location. The full
    # list is only forwarded when collecting a local trace.
    stacks = stacks.first(1) unless @connection.collecting_local_trace_stacks?
    super(api_name, stacks)
  end
end

# Without a local trace, only the public API frame and its immediate caller are
# used. Walk locations until those two are known instead of materializing the
# rest of the Ruby stack.
module SystemPlaywrightRpcMetadataLazy
  private

  def with_logging(title = nil)
    return super if @connection.collecting_local_trace_stacks?

    api_call = nil
    caller_location = nil
    Thread.each_caller_location do |location|
      if api_call
        caller_location = location
        break
      end

      api_call = location if location.absolute_path&.include?("playwright_api")
    end

    return yield(nil) unless api_call

    api_name = "#{File.basename(api_call.absolute_path, ".rb")}##{api_call.label}"
    metadata = build_metadata_payload_from(api_name, caller_location ? [caller_location] : [])
    metadata[:title] = title if title
    yield metadata
  end
end

module SystemPlaywrightTraceStackState
  def collecting_local_trace_stacks?
    @tracing_count > 0 && !remote?
  end
end

if Playwright::VERSION == "1.64.0" && Thread.respond_to?(:each_caller_location)
  Playwright::Connection.prepend(SystemPlaywrightTraceStackState)
  Playwright::Channel.prepend(SystemPlaywrightRpcMetadata)
  Playwright::Channel.prepend(SystemPlaywrightRpcMetadataLazy)
end
