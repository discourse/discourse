# frozen_string_literal: true
require_relative "native-system-driver"

module NativeLifecycleWaits
  def initialize(...)
    super
    @lifecycle_mutex = Mutex.new
    @lifecycle_condition = ConditionVariable.new
  end

  def visit(url)
    start
    previous_loader = @lifecycle_mutex.synchronize { @page.main_loader }
    result = command("Page.navigate", { url: url })
    raise result["errorText"] if result["errorText"]
    wait_for_navigation(previous_loader: previous_loader, new_document: !!result["loaderId"])
  end

  def refresh
    start
    previous_loader = @lifecycle_mutex.synchronize { @page.main_loader }
    command("Page.reload")
    wait_for_navigation(previous_loader: previous_loader, new_document: true)
  end

  def reload
    start
    previous_loader = @lifecycle_mutex.synchronize { @page.main_loader }
    command("Page.reload")
    wait_for_navigation(previous_loader: previous_loader, new_document: true, wait_for_app: false)
  end

  def after_input
    command("Page.enable")
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Capybara.default_max_wait_time
    @lifecycle_mutex.synchronize do
      while @page.input_navigation_pending
        remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
        raise "Native input navigation commit timed out" if remaining <= 0
        @lifecycle_condition.wait(@lifecycle_mutex, remaining)
      end
    end
    settled
  end

  def current_url
    start
    @lifecycle_mutex.synchronize { @page.url }
  end

  def go_back = navigate_history(-1)
  def go_forward = navigate_history(1)

  private

  def navigate_history(offset)
    history = command("Page.getNavigationHistory")
    index = history.fetch("currentIndex") + offset
    return unless index.between?(0, history.fetch("entries").length - 1)
    entry = history.fetch("entries").fetch(index)
    command("Page.navigateToHistoryEntry", { entryId: entry.fetch("id") })
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Capybara.default_max_wait_time
    loop do
      begin
        current = command("Page.getNavigationHistory")
        arrived =
          current.fetch("entries").fetch(current.fetch("currentIndex")).fetch("id") ==
            entry.fetch("id")
        loaded =
          @lifecycle_mutex.synchronize do
            !@page.navigation_pending && @page.loaded_loader == @page.main_loader
          end
        if arrived && loaded && evaluate_script("document.readyState === 'complete'")
          settled
          return
        end
      rescue StandardError => error
        unless error.is_a?(NativeSystemDriver::StaleElement) ||
                 error.message.include?("Not attached to an active page")
          raise
        end
      end
      if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
        raise "Native history navigation timed out"
      end
      sleep 0.01
    end
  end

  def wait_for_navigation(previous_loader:, new_document:, wait_for_app: true)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Capybara.default_max_wait_time
    loop do
      begin
        loader =
          @lifecycle_mutex.synchronize do
            until !@page.navigation_pending && @page.main_loader &&
                    @page.loaded_loader == @page.main_loader &&
                    (!new_document || @page.main_loader != previous_loader)
              remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
              raise "Native navigation lifecycle timed out" if remaining <= 0
              @lifecycle_condition.wait(@lifecycle_mutex, remaining)
            end
            @page.main_loader
          end
        if !wait_for_app ||
             evaluate_script(
               "!document.querySelector('discourse-assets') || !!document.querySelector('#main.ember-application')",
             )
          settled if wait_for_app
          if @lifecycle_mutex.synchronize {
               !@page.navigation_pending && @page.main_loader == loader &&
                 @page.loaded_loader == loader
             }
            return
          end
        end
      rescue NativeSystemDriver::StaleElement
      end
      if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
        raise "Native navigation timed out waiting for Ember"
      end
      sleep 0.01
    end
  end

  def initialize_page(info)
    super
    frame = command("Page.getFrameTree").dig("frameTree", "frame")
    @lifecycle_mutex.synchronize do
      @page.url = frame.fetch("url") + frame.fetch("urlFragment", "")
      @page.navigation_pending = false
      @page.main_frame_id = frame.fetch("id")
      @page.main_loader = frame.fetch("loaderId")
      @page.loaded_loader = nil unless @page.loaded_loader == @page.main_loader
    end
    command("Page.setLifecycleEventsEnabled", { enabled: true })
    if evaluate_script("document.readyState === 'complete'")
      @lifecycle_mutex.synchronize do
        @page.loaded_loader = @page.main_loader if @page.main_loader == frame.fetch("loaderId")
      end
    end
  end

  def report_event(event)
    if state = @pages_by_session[event["sessionId"]]
      params = event["params"] || {}
      @lifecycle_mutex.synchronize do
        case event["method"]
        when "Page.frameNavigated"
          frame = params.fetch("frame")
          unless frame["parentId"]
            state.url = frame.fetch("url") + frame.fetch("urlFragment", "")
            state.input_navigation_pending = false
            state.main_frame_id = frame.fetch("id")
            state.main_loader = frame.fetch("loaderId")
            @lifecycle_condition.broadcast
          end
        when "Page.frameRequestedNavigation"
          if params["frameId"] == state.main_frame_id && params["disposition"] == "currentTab"
            state.input_navigation_pending = true
            @lifecycle_condition.broadcast
          end
        when "Page.navigatedWithinDocument"
          if params["frameId"] == state.main_frame_id
            state.url = params.fetch("url")
            state.input_navigation_pending = false
            @lifecycle_condition.broadcast
          end
        when "Page.frameStartedLoading"
          if params["frameId"] == state.main_frame_id
            state.navigation_pending = true
            @lifecycle_condition.broadcast
          end
        when "Page.frameStoppedLoading"
          if params["frameId"] == state.main_frame_id
            state.input_navigation_pending = false
            state.navigation_pending = false
            @lifecycle_condition.broadcast
          end
        when "Page.lifecycleEvent"
          if params["frameId"] == state.main_frame_id && params["name"] == "load"
            state.loaded_loader = params.fetch("loaderId")
            @lifecycle_condition.broadcast
          end
        end
      end
    end
    super
  end
end

NativeSystemDriver.prepend(NativeLifecycleWaits)
