# frozen_string_literal: true

# In-page batched finder ("capyq") for the Playwright Capybara driver.
#
# Stock Capybara resolution costs one protocol round trip for the
# querySelectorAll plus one additional round trip per candidate that the
# visibility (and text) filters examine afterwards. This registers a custom
# Playwright selector engine that resolves the CSS/XPath query, applies the
# same text-fragment prefilter Capybara's selenium driver ships
# (case-insensitive textContent containment), and applies the exact
# visibility predicate Node#visible? uses - all inside the page, in the single
# querySelectorAll protocol message. Only surviving elements are materialized
# as element handles, and the driver stamps initial_cache[:visible] on the
# returned nodes so Capybara's matches_visibility_filters? short-circuits
# without any further IPC (capybara 3.40.0 selector_query.rb:568-577).
#
# The fast path engages only for queries whose SelectorQuery hints make it
# provably equivalent to the stock path; everything else - and every query
# issued when the engine could not be registered, or with
# CAPYBARA_PLAYWRIGHT_FAST_FIND=0 - takes the stock Playwright engine path,
# byte-for-byte identical to before.
#
# This is a spec/support prepend over the released capybara-playwright-driver
# gem (no vendoring): the FastFinder module, the SelectorQuery hint
# extension, fast-path overrides of Browser/Node #find_css/#find_xpath, an
# initial_cache-aware Node#initialize, and selector-engine registration in
# BrowserRunner#start.

require "json"
require "capybara/playwright"

module Capybara
  module Playwright
    module FastFinder
      ENGINE_NAME = "capyq"

      # The script is evaluated by Playwright's injected script as
      # `(${source})` and must yield the engine object. The selector body is
      # base64(JSON) so it can never collide with Playwright's `>>` selector
      # chaining syntax or quoting rules.
      #
      # isVisible() is the byte-identical predicate from Node#visible?'s
      # payload JS (minus the isConnected staleness throw: engine results are
      # connected by construction; detached scoped roots throw at entry
      # below, which assert_element_not_stale maps to StaleReferenceError).
      ENGINE_SOURCE = <<~JAVASCRIPT
        (() => {
          function isVisible(el) {
            if (el.tagName == 'AREA'){
              const map_name = document.evaluate('./ancestor::map/@name', el, null, XPathResult.STRING_TYPE, null).stringValue;
              el = document.querySelector(`img[usemap='#${map_name}']`);
              if (!el){
                return false;
              }
            }
            var forced_visible = false;
            while (el) {
              const style = window.getComputedStyle(el);
              if (style.visibility == 'visible')
                forced_visible = true;
              if ((style.display == 'none') ||
                  ((style.visibility == 'hidden') && !forced_visible) ||
                  (parseFloat(style.opacity) == 0)) {
                return false;
              }
              var parent = el.parentElement;
              if (parent && (parent.tagName == 'DETAILS') && !parent.open && (el.tagName != 'SUMMARY')) {
                return false;
              }
              el = parent;
            }
            return true;
          }

          function resolve(root, body) {
            const spec = JSON.parse(atob(body));
            if (spec.s && root.nodeType === Node.ELEMENT_NODE && !root.isConnected) {
              throw new Error('Element is not attached to the DOM');
            }
            let els;
            if (spec.c !== undefined) {
              els = Array.from(root.querySelectorAll(spec.c));
            } else {
              // Replicates Playwright's xpath engine (injectedScriptSource XPathEngine.queryAll).
              let xpath = spec.x;
              if (xpath.startsWith('/') && root.nodeType !== Node.DOCUMENT_NODE)
                xpath = '.' + xpath;
              els = [];
              const doc = root.ownerDocument || root;
              if (doc) {
                const it = doc.evaluate(xpath, root, null, XPathResult.ORDERED_NODE_ITERATOR_TYPE);
                for (let node = it.iterateNext(); node; node = it.iterateNext()) {
                  if (node.nodeType === Node.ELEMENT_NODE)
                    els.push(node);
                }
              }
            }
            if (spec.t !== undefined) {
              // Same semantics as capybara's selenium filter_by_text
              // (capybara 3.40.0 selenium/extensions/find.rb:44-52).
              els = els.filter((el) => {
                const content = el.textContent.toLowerCase();
                return spec.t.every((txt) => content.indexOf(txt.toLowerCase()) != -1);
              });
            }
            if (spec.v !== undefined) {
              els = els.filter((el) => isVisible(el) === spec.v);
            }
            return els;
          }

          return {
            queryAll(root, body) {
              return resolve(root, body);
            },
            query(root, body) {
              return resolve(root, body)[0];
            },
          };
        })()
      JAVASCRIPT

      @disabled = ENV["CAPYBARA_PLAYWRIGHT_FAST_FIND"] == "0"

      class << self
        def enabled?
          !@disabled
        end

        def disable!
          @disabled = true
        end

        # Registers the engine on a freshly created Playwright connection.
        # Must run before any browser context exists on that connection.
        # Any failure (remote connection modes without a Playwright handle,
        # future protocol changes) permanently falls back to the stock path.
        def ensure_registered(playwright_execution)
          return unless enabled?

          playwright_execution.playwright.selectors.register(ENGINE_NAME, script: ENGINE_SOURCE)
          unless @registered_logged
            @registered_logged = true
            warn "[capyq] selector engine registered"
          end
        rescue StandardError, NotImplementedError => e
          warn "[capyq] disabled: #{e.class}: #{e.message}"
          disable!
        end

        # Returns [engine_selector, initial_cache] when the in-page fast path
        # applies, or nil for the stock path.
        def plan(hints, css: nil, xpath: nil, scoped: false)
          return nil unless enabled?
          # Only queries dispatched through the patched SelectorQuery carry
          # :visibility_mode; anything else (direct driver calls) stays stock.
          return nil unless hints.key?(:visibility_mode)
          return nil unless hints[:obscured].nil?
          # With allow_self, Capybara exempts the scope node itself from ALL
          # filters (selector_query.rb:119 returns true for the resolved node
          # before the visibility/text filters run) - e.g. fill_in(with:) on
          # ace's permanently opacity-0 `.ace_text-input` textarea must match
          # the scope despite `visible: :visible`. The in-page filter cannot
          # honor that exemption, so these (rare, element-scoped action)
          # queries keep the stock path.
          return nil if hints[:allow_self]
          # Native querySelectorAll raises SyntaxError for selectors with a
          # leading combinator (`> x`, `+ x`, `~ x`) that Playwright's own CSS
          # engine accepts with an implicit :scope (post_stream_spec's
          # `> [data-post-number=...]`). Decline conservatively, including
          # after top-level commas; a quoted comma can only over-decline,
          # which just means the stock path.
          return nil if css&.match?(/\A\s*[>+~]|,\s*[>+~]/)

          filter_visible =
            case hints[:visibility_mode]
            when :visible
              true
            when :hidden
              false
            end
          texts = hints[:texts] || []
          return nil if filter_visible.nil? && texts.empty?

          spec = {}
          spec[:c] = css if css
          spec[:x] = xpath if xpath
          spec[:t] = texts unless texts.empty?
          spec[:v] = filter_visible unless filter_visible.nil?
          spec[:s] = 1 if scoped

          body = [JSON.generate(spec, ascii_only: true)].pack("m0")
          cache = filter_visible.nil? ? {} : { visible: filter_visible }
          ["#{ENGINE_NAME}=#{body}", cache]
        end
      end
    end

    # Counterpart of Capybara::Queries::SelectorQuery#find_nodes_by_selector_format
    # (capybara 3.40.0): identical hint construction and dispatch, plus the
    # extra hints the fast path needs - the resolved visibility mode (the
    # stock :uses_visibility hint cannot distinguish :visible from :hidden)
    # and the :obscured / :allow_self options whose filter semantics the
    # in-page path cannot reproduce. Drivers with positional-only finder
    # signatures (e.g. rack_test's driver-level finders) keep receiving no
    # hints via the unchanged arity dispatch.
    module SelectorQueryExtraHints
      private

      def find_nodes_by_selector_format(node, exact)
        hints = {}
        hints[:uses_visibility] = true unless visible == :all
        hints[:texts] = text_fragments unless selector_format == :xpath
        hints[:styles] = options[:style] if use_default_style_filter?
        hints[:position] = true if use_spatial_filter?
        hints[:visibility_mode] = visible
        hints[:obscured] = options[:obscured]
        hints[:allow_self] = options[:allow_self]

        case selector_format
        when :css
          if node.method(:find_css).arity == 1
            node.find_css(css)
          else
            node.find_css(css, **hints)
          end
        when :xpath
          if node.method(:find_xpath).arity == 1
            node.find_xpath(xpath(exact))
          else
            node.find_xpath(xpath(exact), **hints)
          end
        else
          raise ArgumentError, "Unknown format: #{selector_format}"
        end
      end
    end

    # Fast-path overrides for the page-level (unscoped) finders.
    module BrowserFastFind
      def find_xpath(query, **options)
        assert_page_alive do
          selector, initial_cache = FastFinder.plan(options, xpath: query)
          if selector
            @playwright_page
              .capybara_current_frame
              .query_selector_all(selector)
              .map { |el| Node.new(@driver, @internal_logger, @playwright_page, el, initial_cache) }
          else
            @playwright_page
              .capybara_current_frame
              .query_selector_all("xpath=#{query}")
              .map { |el| Node.new(@driver, @internal_logger, @playwright_page, el) }
          end
        end
      end

      def find_css(query, **options)
        assert_page_alive do
          selector, initial_cache = FastFinder.plan(options, css: query)
          if selector
            @playwright_page
              .capybara_current_frame
              .query_selector_all(selector)
              .map { |el| Node.new(@driver, @internal_logger, @playwright_page, el, initial_cache) }
          else
            @playwright_page
              .capybara_current_frame
              .query_selector_all(query)
              .map { |el| Node.new(@driver, @internal_logger, @playwright_page, el) }
          end
        end
      end
    end

    # Fast-path overrides for the element-scoped finders, plus an
    # initial_cache-aware initializer so the stamped visibility short-circuits
    # Capybara's per-node filter IPC. ShadowRootNode scopes (a Node subclass)
    # stay on the stock engine, which pierces open shadow roots. Unlike the
    # vendored variant this keeps the stock staleness probe (@element.enabled?
    # in assert_element_not_stale) rather than folding it into the engine
    # call, trading one round trip for a smaller, lower-risk patch surface.
    module NodeFastFind
      def initialize(driver, internal_logger, page, element, initial_cache = {})
        super(driver, internal_logger, page, element)
        @initial_cache = initial_cache unless initial_cache.empty?
      end

      def find_xpath(query, **options)
        selector, initial_cache =
          (instance_of?(Node) ? FastFinder.plan(options, xpath: query, scoped: true) : nil)
        if selector
          assert_element_not_stale do
            @element
              .query_selector_all(selector)
              .map { |el| Node.new(@driver, @internal_logger, @page, el, initial_cache) }
          end
        else
          assert_element_not_stale do
            @element
              .query_selector_all("xpath=#{query}")
              .map { |el| Node.new(@driver, @internal_logger, @page, el) }
          end
        end
      end

      def find_css(query, **options)
        selector, initial_cache =
          (instance_of?(Node) ? FastFinder.plan(options, css: query, scoped: true) : nil)
        if selector
          assert_element_not_stale do
            @element
              .query_selector_all(selector)
              .map { |el| Node.new(@driver, @internal_logger, @page, el, initial_cache) }
          end
        else
          assert_element_not_stale do
            @element
              .query_selector_all(query)
              .map { |el| Node.new(@driver, @internal_logger, @page, el) }
          end
        end
      end
    end

    # Registers the selector engine on the Playwright connection once it is
    # established, before any browser context is created.
    module BrowserRunnerRegister
      def start
        browser = super
        FastFinder.ensure_registered(@playwright_execution) if @playwright_execution
        browser
      end
    end
  end
end

Capybara::Queries::SelectorQuery.prepend(Capybara::Playwright::SelectorQueryExtraHints)
Capybara::Playwright::Browser.prepend(Capybara::Playwright::BrowserFastFind)
Capybara::Playwright::Node.prepend(Capybara::Playwright::NodeFastFind)
Capybara::Playwright::BrowserRunner.prepend(Capybara::Playwright::BrowserRunnerRegister)
