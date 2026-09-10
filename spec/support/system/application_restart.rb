# frozen_string_literal: true
require "base64"
require "timeout"

if ENV["SYSTEM_TEST_REUSE_APPLICATION"] == "1"
  module SystemTestApplicationDocumentSignature
    REFRESHED_HEAD_SELECTOR = [
      "title",
      'meta[name="description"]',
      'meta[name="csrf-token"]',
      'meta[name="csrf-param"]',
      'meta[name="discourse-track-view-session-id"]',
      'link[rel="canonical"]',
      'link[rel="next"]',
      'link[rel="prev"]',
      'meta[property^="og:"]',
      'meta[property^="article:"]',
      'meta[name^="twitter:"]',
      'link[rel~="alternate"]',
      'script[type="application/ld+json"]',
    ].join(", ").freeze

    def call(env)
      status, headers, body = super
      unless (headers["content-type"] || headers["Content-Type"])&.include?("text/html")
        return status, headers, body
      end

      html = +""
      body.each { |part| html << part }
      body.close if body.respond_to?(:close)
      if html.include?('id="data-discourse-setup"')
        document = Nokogiri.HTML(html)
        document.css(
          "#data-discourse-setup, #data-preloaded, noscript, #{REFRESHED_HEAD_SELECTOR}",
        ).remove
        document.at_css("head").xpath(".//text()[normalize-space(.)='']").remove
        document.css("[nonce]").each { |node| node.remove_attribute("nonce") }
        policies =
          headers
            .filter_map do |name, value|
              if %w[
                   content-security-policy
                   content-security-policy-report-only
                   cross-origin-opener-policy
                   cross-origin-embedder-policy
                   permissions-policy
                   referrer-policy
                 ].include?(name.downcase)
                [name.downcase, value.gsub(/'nonce-[^']+'/, "'nonce'")]
              end
            end
            .sort
        signature = Digest::SHA256.hexdigest(document.to_html + policies.to_json)
        html =
          html.sub(
            "</head>",
            %(<meta name="system-test-document-key" content="#{signature}"></head>),
          )
        headers.delete("Content-Length")
        headers["content-length"] = html.bytesize.to_s
      end
      [status, headers, [html]]
    end
  end
  BlockRequestsMiddleware.prepend(SystemTestApplicationDocumentSignature)

  module SystemTestApplicationRestart
    TEARDOWN = <<~JAVASCRIPT
      async () => {
        const previous = window.Discourse;
        const app = previous.application;

        previous.lookup('service:screen-track').stop();
        await window.clientSettled(5000);
        window.MessageBus?.stop();
        app._runInitializer('instanceInitializers', (_, initializer) => initializer.teardown?.());
        previous.lookup('service:current-user')?.statusManager?.stopTrackingStatus();
        require('discourse/initializers/inject-discourse-objects').default.teardown();
        require('@ember/runloop').run(() => {
          for (const model of window.__systemTestApplicationModels || []) require('@ember/object').default.prototype.destroy.call(model);
          window.__systemTestApplicationModels = [];
          previous.destroy();
        });
        if (!previous.isDestroyed) throw new Error('Previous application owner was not destroyed');
        require('@ember/runloop')._backburner.cancelTimers();
        require('discourse/services/store').flushMap();
        window.__systemTestApplicationRestartState = { previous, app };
      }
    JAVASCRIPT
    BOOT = <<~JAVASCRIPT
      async ({ url, html, replaceHistory }) => {
        const { previous, app } = window.__systemTestApplicationRestartState;
        delete window.__systemTestApplicationRestartState;
        const fresh = new DOMParser().parseFromString(html, 'text/html');
        document.querySelector('#hidden-login-form')?.reset();
        if (replaceHistory) history.replaceState(null, '', url);
        else if (location.href !== url) history.pushState(null, '', url);
        const refreshedHeadSelector = #{SystemTestApplicationDocumentSignature::REFRESHED_HEAD_SELECTOR.to_json};
        document.head.querySelectorAll(refreshedHeadSelector).forEach(element => element.remove());
        document.head.append(...fresh.head.querySelectorAll(refreshedHeadSelector));
        document.querySelector('#data-preloaded').textContent = fresh.querySelector('#data-preloaded').textContent;
        document.querySelector('#data-discourse-setup').replaceWith(fresh.querySelector('#data-discourse-setup'));
        if (document.querySelector('#data-discourse-setup').dataset.isStaff === 'true') await window.moduleBroker.loadAdmin();
        require('discourse/lib/preload-store').default.reset();
        require('discourse/lib/preload-store').populatePreloadStore();
        const next = app.buildInstance();
        require('discourse/lib/get-owner').setDefaultOwner(next.__container__);
        require('discourse/models/user').default.resetCurrent();
        require('discourse/models/site').default.resetCurrent();
        require('discourse/models/session').default.resetCurrent();
        require('discourse/initializers/discourse-bootstrap').default.initialize(next);
        require('discourse/initializers/inject-discourse-objects').default.initialize(next);
        require('discourse/initializers/map-routes').default.initialize(next);
        await next.boot({isBrowser: true, rootElement: '#main'});
        require('discourse/lib/url').setURLContainer(next.__container__);
        await next.visit(new URL(url).pathname + new URL(url).search);
        const deadline = performance.now() + 5000;
        while (!window.Discourse || window.Discourse === previous || window.Discourse.isDestroying) {
          if (performance.now() > deadline) throw new Error('Application instance did not restart');
          await new Promise(resolve => setTimeout(resolve, 1));
        }
        await window.clientSettled(5000);
        return previous.isDestroyed && window.Discourse !== previous;
      }
    JAVASCRIPT
    TRACK_MODELS = <<~JAVASCRIPT
      if (!window.__systemTestApplicationModels) {
        window.__systemTestApplicationModels = [];
        const storePrototype = require('discourse/services/store').default.prototype;
        const build = storePrototype._build;
        storePrototype._build = function (...args) {
          const model = build.apply(this, args);
          window.__systemTestApplicationModels.push(model);
          return model;
        };
      }
    JAVASCRIPT

    CapturedResponse = Struct.new(:status, :headers, keyword_init: true)
    private_constant :CapturedResponse, :TEARDOWN, :BOOT, :TRACK_MODELS

    def with_playwright_page(&block)
      infrastructure = application_restart_infrastructure_call?
      super do |browser_page|
        unless infrastructure
          browser_page.instance_variable_set(:@application_restart_customized, true)
        end
        block.call(browser_page)
      end
    end

    %i[execute_script evaluate_script evaluate_async_script].each do |method_name|
      define_method(method_name) do |*args|
        @application_restart_scripted_document =
          true unless application_restart_infrastructure_call?
        super(*args)
      end
    end

    def application_restart_pending?
      return false unless @application_restart_pending

      with_playwright_page do |browser_page|
        browser_page.evaluate(
          "() => window.__systemTestApplicationRestartState?.previous.isDestroyed === true",
        )
      end
    end

    def reset!
      unless !application_restart_pending? && restart_supported?
        @application_restart_pending = false
        @application_restart_count = 0
        @application_restart_scripted_document = false
        return super
      end

      with_playwright_page do |browser_page|
        browser_page.evaluate(TEARDOWN)
        session = browser_page.context.new_cdp_session(browser_page)
        begin
          session.send_message("Page.resetNavigationHistory")
          session.send_message(
            "Storage.clearDataForOrigin",
            params: {
              origin: "*",
              storageTypes: "all",
            },
          )
        ensure
          session.detach
        end
        browser_page.evaluate("() => { localStorage.clear(); sessionStorage.clear(); }")
        browser_page.context.clear_cookies
        browser_page.context.clear_permissions
        viewport = @page_options.value[:viewport]
        browser_page.set_viewport_size(viewport) if viewport
      end
      @application_restart_pending = true
    end

    def visit(url)
      base_url = Capybara.app_host || Capybara.default_host
      target_url = base_url ? (Addressable::URI.parse(base_url) + url).to_s : url
      navigate_with_application_restart(url: target_url) { super }
    end

    def refresh
      result = super
      track_native_document
      result
    end

    def resize_window_to(handle, width, height)
      if application_restart_pending?
        with_playwright_page { |browser_page| browser_page.goto("about:blank") }
        track_native_document
      end

      super
    end

    private

    def application_restart_infrastructure_call?
      locations = caller_locations(2)
      return true if locations.first&.absolute_path == __FILE__

      caller =
        locations.find do |location|
          path = location.absolute_path || location.path
          path.start_with?(Rails.root.to_s) && path != __FILE__ && !path.include?("/vendor/") &&
            !path.include?("/node_modules/")
        end
      return false unless caller
      path = caller.absolute_path || caller.path
      if [
           Rails.root.join("spec/rails_helper.rb").to_s,
           Rails.root.join("spec/support/system/capybara_patches.rb").to_s,
         ].include?(path)
        return true
      end
      path == Rails.root.join("spec/support/system_helpers.rb").to_s &&
        caller.base_label == "sign_in"
    end

    def restart_supported?
      example = RSpec.current_example
      return false unless example && !example.exception
      return false if @application_restart_scripted_document
      return false if example.metadata.values_at(:time, :timezone, :video, :trace).any?
      return false if (@application_restart_count || 0) >= 16
      if callback_on_save_screenrecord? || callback_on_save_screenshot? || @callback_on_save_trace
        return false
      end
      return false if @browser&.instance_variable_get(:@context_downloaded)
      return false unless @browser && window_handles.length == 1

      with_playwright_page do |browser_page|
        next false if browser_page.instance_variable_get(:@application_restart_customized)

        browser_page.evaluate(<<~JAVASCRIPT, arg: application_restart_pending?)
          (pending) => {
            const available = pending
              ? !!window.__systemTestApplicationRestartState
              : !!window.Discourse && !window.Discourse.isDestroying;
            return available && setTimeout.toString().includes('[native code]');
          }
        JAVASCRIPT
      end
    end

    def navigation_supports_restart?(url)
      return false if SiteSetting.enable_discourse_connect
      return false if SiteSetting.login_required || !SiteSetting.enable_local_logins

      target = URI(url)
      current = URI(current_url)
      return false if target.fragment
      if [target.query, current.query].compact.any? { |query|
           URI.decode_www_form(query).any? { |name, _value| name == "safe_mode" }
         }
        return false
      end
      unless [target.scheme, target.host, target.port] ==
               [current.scheme, current.host, current.port]
        return false
      end
      path = target.path.delete_prefix(GlobalSetting.relative_url_root.to_s)
      return false if path.match?(%r{\A/(?:auth|session|login|signup|invites|user-api-key)(?:/|\z)})
      restart_supported?
    end

    def document_compatibility(html)
      document = Nokogiri.HTML5(html)
      preload = document.at_css("#data-preloaded")
      signature = document.at_css('meta[name="system-test-document-key"]')
      sprite = document.at_css("#data-discourse-setup")&.[]("data-svg-sprite-path")
      assets =
        document
          .css("script[src], link[rel=stylesheet], link[rel=modulepreload]")
          .filter_map do |element|
            next if sprite && sprite != "" && element["src"] == sprite
            [element.name, element["src"], element["href"], element["type"], element["media"]]
          end
      {
        signature: signature&.[]("content"),
        themes: preload && JSON.parse(preload.text)["activatedThemes"],
        assets: [sprite, assets],
        authentication_form: !document.at_css("#hidden-login-form").nil?,
        preload: !preload.nil?,
      }
    end

    def track_native_document
      @application_restart_pending = false
      tracked_before = with_playwright_page { |browser_page| browser_page.evaluate(<<~JAVASCRIPT) }
          () => {
            const trackedBefore = !!window.__systemTestApplicationModels;
            if (window.Discourse && !window.Discourse.isDestroying) { #{TRACK_MODELS} }
            return trackedBefore;
          }
        JAVASCRIPT
      unless tracked_before
        @application_restart_count = 0
        @application_restart_scripted_document = false
      end
    end

    def navigate_with_application_restart(url:, refresh: false)
      unless navigation_supports_restart?(url)
        if @application_restart_pending && URI(url).fragment && !refresh
          with_playwright_page { |browser_page| browser_page.goto("about:blank") }
        end
        result = yield
        track_native_document
        return result
      end

      captured = nil
      navigation_error = nil
      callback_error = nil
      native_result = nil
      was_pending = application_restart_pending?
      with_playwright_page do |browser_page|
        current =
          document_compatibility(browser_page.evaluate("() => document.documentElement.outerHTML"))
        session = browser_page.context.new_cdp_session(browser_page)
        begin
          session.send_message("Page.enable")
          frame = session.send_message("Page.getFrameTree").fetch("frameTree").fetch("frame")
          frame_id = frame.fetch("id")
          native_document_committed = false
          native_response = nil
          session.on(
            "Page.frameNavigated",
            ->(event) do
              committed = event.fetch("frame")
              if committed["id"] == frame_id && committed["loaderId"] != frame["loaderId"]
                native_document_committed = true
              end
            end,
          )
          session.on(
            "Network.responseReceived",
            ->(event) do
              if event["frameId"] == frame_id && event["type"] == "Document"
                response = event.fetch("response")
                native_response =
                  CapturedResponse.new(
                    status: response.fetch("status"),
                    headers: response.fetch("headers").transform_keys(&:downcase),
                  )
              end
            end,
          )
          session.send_message("Network.enable")
          events = Queue.new
          session.on("Fetch.requestPaused", ->(event) { events << event })
          response_worker =
            Thread.new do
              first_document = true
              while (event = events.pop)
                request_id = event.fetch("requestId")
                begin
                  headers = event.fetch("responseHeaders", [])
                  content_type =
                    headers
                      .find { |header| header.fetch("name").downcase == "content-type" }
                      &.fetch("value") || ""
                  eligible =
                    first_document && event["frameId"] == frame_id &&
                      event.fetch("request").fetch("url") == url &&
                      event["responseStatusCode"] == 200 && content_type.include?("text/html")
                  first_document = false if event["frameId"] == frame_id
                  if eligible
                    body =
                      session.send_message(
                        "Fetch.getResponseBody",
                        params: {
                          requestId: request_id,
                        },
                      )
                    html = body.fetch("body")
                    html = Base64.decode64(html).force_encoding(Encoding::UTF_8) if body[
                      "base64Encoded"
                    ]
                    fresh = document_compatibility(html)
                    eligible = current[:preload] && current[:signature] && current == fresh
                  end
                  unless eligible
                    session.send_message(
                      "Fetch.continueResponse",
                      params: {
                        requestId: request_id,
                      },
                    )
                    next
                  end

                  response_headers =
                    headers.reject do |header|
                      %w[content-length content-encoding transfer-encoding].include?(
                        header.fetch("name").downcase,
                      )
                    end
                  session.send_message(
                    "Fetch.fulfillRequest",
                    params: {
                      requestId: request_id,
                      responseCode: 204,
                      responseHeaders: response_headers,
                      body: "",
                    },
                  )
                  captured = {
                    html: html,
                    response:
                      CapturedResponse.new(
                        status: 200,
                        headers:
                          headers.to_h do |header|
                            [header.fetch("name").downcase, header.fetch("value")]
                          end,
                      ),
                  }
                rescue StandardError => error
                  callback_error ||= error
                  session.send_message("Fetch.continueResponse", params: { requestId: request_id })
                end
              end
            end

          begin
            session.send_message(
              "Fetch.enable",
              params: {
                patterns: [{ urlPattern: "*", resourceType: "Document", requestStage: "Response" }],
              },
            )
            begin
              native_result = yield
            rescue Playwright::Error => error
              navigation_error = error
            end
          ensure
            events << nil
            worker_finished = response_worker.join(5)
            begin
              Timeout.timeout(3) { session.send_message("Fetch.disable") }
            rescue StandardError => error
              cleanup_error = error
            ensure
              response_worker.kill unless worker_finished
              response_worker.join(1)
            end
            unless worker_finished
              callback_error ||=
                RuntimeError.new("Application restart response collection did not finish")
            end
            begin
              response_worker.value
            rescue StandardError => error
              callback_error ||= error
            end
          end

          raise callback_error if callback_error
          unless captured
            raise navigation_error if navigation_error
            raise cleanup_error if cleanup_error
            track_native_document
            return native_result
          end
          if navigation_error && !navigation_error.message.include?("net::ERR_ABORTED")
            raise navigation_error
          end
          raise cleanup_error if cleanup_error

          browser_page.capybara_set_last_response(captured.fetch(:response))
          browser_page.evaluate(TEARDOWN) unless was_pending
          begin
            outcome =
              browser_page.evaluate(
                BOOT,
                arg: {
                  url: url,
                  html: captured.fetch(:html),
                  replaceHistory: was_pending,
                },
              )
          rescue Playwright::Error => error
            unless native_document_committed &&
                     error.message.include?("Execution context was destroyed")
              raise
            end
          end
          if native_document_committed
            browser_page.wait_for_load_state(state: "load")
            raise "Native navigation response was not observed" unless native_response
            browser_page.capybara_set_last_response(native_response)
            track_native_document
            return
          end
          raise "Application restart failed" unless outcome == true
          browser_page.evaluate("() => { #{TRACK_MODELS} }")
        ensure
          primary_error = $!
          begin
            Timeout.timeout(3) { session.detach }
          rescue StandardError
            if primary_error
              warn "SYSTEM_TEST_APPLICATION_RESTART_CLEANUP_FAILED"
            else
              raise
            end
          end
        end
      end
      @application_restart_pending = false
      @application_restart_count = (@application_restart_count || 0) + 1
      puts "SYSTEM_TEST_APPLICATION_RESTART #{@application_restart_count}"
      nil
    end
  end

  module SystemTestApplicationPageChanges
    def on(event, callback)
      if Thread.current[:application_restart_logger_page].equal?(self)
        (@application_restart_logger_callbacks ||= []) << [event, callback]
      else
        registration = caller_locations(1, 1).first
        owned_registration =
          [
            Capybara::Playwright::PageExtension.instance_method(:capybara_initialize),
            Capybara::Playwright::Browser.instance_method(:create_page),
          ].any? do |method|
            registration.absolute_path == method.source_location.first &&
              registration.base_label == method.name.to_s
          end
        @application_restart_customized = true unless owned_registration
      end
      super
    end

    %i[
      once
      add_init_script
      expose_binding
      expose_function
      route
      route_from_har
      route_web_socket
    ].each do |method_name|
      define_method(method_name) do |*args, **options, &block|
        @application_restart_customized = true
        super(*args, **options, &block)
      end
    end
  end

  module SystemTestApplicationLogger
    def initialize(browser_page)
      browser_page
        .instance_variable_get(:@application_restart_logger_callbacks)
        &.each { |event, callback| browser_page.off(event, callback) }
      browser_page.instance_variable_set(:@application_restart_logger_callbacks, [])
      Thread.current[:application_restart_logger_page] = browser_page
      super
    ensure
      Thread.current[:application_restart_logger_page] = nil
    end
  end

  RSpec.configure do |config|
    config.before(:suite) do
      Capybara::Playwright::Driver.prepend(SystemTestApplicationRestart)
      Playwright::Page.prepend(SystemTestApplicationPageChanges)
      PlaywrightLogger.prepend(SystemTestApplicationLogger)
    end

    config.prepend_before(:each, type: :system) do |example|
      page.driver.reset! if example.metadata.values_at(:time, :timezone, :video, :trace).any?
    end
  end
end
