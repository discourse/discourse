# frozen_string_literal: true
module NativeBrowserFrames
  def initialize(...)
    super
    @frame_contexts = {}
    @frame_targets = {}
    @frame_stacks = Hash.new { |hash, target| hash[target] = [] }
  end

  def native_frame
    @page && @frame_stacks[@page.target].last
  end

  def native_session
    native_frame ? @frame_contexts.fetch(native_frame).fetch(:session) : @page&.session
  end

  def switch_to_frame(frame)
    start
    stack = @frame_stacks[@page.target]
    case frame
    when :parent
      stack.pop
    when :top
      stack.clear
    else
      owner = frame.native
      identifier = command("DOM.describeNode", { objectId: owner }).dig("node", "frameId")
      raise ArgumentError, "Element does not own a frame" unless identifier
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Capybara.default_max_wait_time
      until @frame_contexts[identifier]
        unless @frame_targets[identifier]
          target =
            command("Target.getTargets", {}, browser: true)
              .fetch("targetInfos")
              .find { |info| info["targetId"] == identifier }
          if target
            session =
              command(
                "Target.attachToTarget",
                { targetId: identifier, flatten: true },
                browser: true,
              ).fetch("sessionId")
            @frame_targets[identifier] = session
            command("Runtime.enable", {}, session: session)
          end
        end
        if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
          raise Playwright::TimeoutError.new(
                  message: "Frame execution context did not become available",
                )
        end
        sleep 0.01
      end
      stack << identifier
    end
    nil
  end

  def command(method, params = {}, browser: false, session: nil)
    unless browser || session
      owner = params[:objectId]
      if owner.is_a?(NativeElementHandle)
        session = owner.session
        if owner.frame && %w[Driver.click Driver.hover].include?(method)
          params = params.merge(frameCoordinates: true)
        end
      elsif native_frame &&
            (method.start_with?("Runtime.") || %w[Driver.find Driver.sendKeys].include?(method))
        context = @frame_contexts[native_frame]
        unless context
          raise NativeSystemDriver::StaleElement, "Frame execution context is unavailable"
        end
        session = context.fetch(:session)
        if %w[Runtime.evaluate Driver.find].include?(method) && !params.key?(:contextId)
          params = params.merge(contextId: context.fetch(:context))
        end
      end
    end
    super(method, params, browser: browser, session: session)
  end

  def reset!
    @frame_stacks.clear
    super
  end

  private

  def report_event(event)
    params = event["params"] || {}
    session = event["sessionId"]
    case event["method"]
    when "Runtime.executionContextCreated"
      context = params.fetch("context")
      if context.dig("auxData", "isDefault")
        @frame_contexts[context.dig("auxData", "frameId")] = {
          session: session,
          context: context.fetch("id"),
        }
      end
    when "Runtime.executionContextDestroyed"
      @frame_contexts.delete_if do |_, frame_context|
        frame_context[:session] == session &&
          frame_context[:context] == params["executionContextId"]
      end
    when "Runtime.executionContextsCleared"
      @frame_contexts.delete_if { |_, frame_context| frame_context[:session] == session }
    when "Target.detachedFromTarget"
      detached = params["sessionId"]
      @frame_contexts.delete_if { |_, frame_context| frame_context[:session] == detached }
      @frame_targets.delete_if { |_, target_session| target_session == detached }
    end
    super
  end
end
