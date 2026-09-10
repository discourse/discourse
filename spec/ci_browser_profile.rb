# frozen_string_literal: true

if ENV["DISCOURSE_CI_BROWSER_PROFILE"] == "1" && ENV["TEST_ENV_NUMBER"] == "1"
  require "json"

  module CiBrowserProfile
    METRICS = %w[
      TaskDuration
      ScriptDuration
      LayoutDuration
      RecalcStyleDuration
      LayoutCount
      RecalcStyleCount
    ].freeze
    @pages = {}
    @totals = METRICS.to_h { |name| [name, 0.0] }
    @counts = {
      pages: 0,
      samples: 0,
      closed_pages: 0,
      missing_metrics: 0,
      counter_resets: 0,
      errors: 0,
    }

    def self.metrics(session)
      values = session.send_message("Performance.getMetrics").fetch("metrics")
      selected =
        values.to_h { |metric| [metric.fetch("name"), metric.fetch("value")] }.slice(*METRICS)
      unless selected.size == METRICS.size &&
               selected.values.all? { |value| value.is_a?(Numeric) && value.finite? && value >= 0 }
        @counts[:missing_metrics] += 1
        return
      end
      selected
    end

    def self.attach(browser:, page:)
      @counts[:pages] += 1
      session = page.context.new_cdp_session(page)
      session.send_message("Performance.enable", params: { timeDomain: "threadTicks" })
      baseline = metrics(session)
      unless baseline
        session.detach
        return
      end
      record = { session: session, baseline: baseline, closed: false }
      page.on("close", -> { record[:closed] = true })
      (@pages[browser] ||= []) << record
    rescue StandardError
      @counts[:errors] += 1
      begin
        session&.detach
      rescue StandardError
        @counts[:errors] += 1
      end
    end

    def self.collect(browser)
      records = @pages.delete(browser) || []
      records.each do |record|
        if record[:closed]
          @counts[:closed_pages] += 1
          next
        end
        current = metrics(record[:session])
        next unless current
        deltas = METRICS.to_h { |name| [name, current.fetch(name) - record[:baseline].fetch(name)] }
        if deltas.values.any?(&:negative?)
          @counts[:counter_resets] += 1
          next
        end
        deltas.each { |name, value| @totals[name] += value }
        @counts[:samples] += 1
      rescue StandardError
        @counts[:errors] += 1
      ensure
        begin
          record[:session].detach
        rescue StandardError
          @counts[:errors] += 1
        end
      end
    rescue StandardError
      @counts[:errors] += 1
    end

    def self.report
      @pages.keys.each { |browser| collect(browser) }
      metrics = @counts[:samples].positive? ? @totals : nil
      puts "CI_BROWSER_CPU #{JSON.generate(worker: 1, time_domain: "threadTicks", metrics: metrics, counts: @counts)}"
    rescue StandardError
      nil
    end

    module Browser
      def soft_reset!(...)
        CiBrowserProfile.collect(self)
        super
      end

      def clear_browser_contexts(...)
        CiBrowserProfile.collect(self)
        super
      end

      private

      def create_page(...)
        super.tap { |page| CiBrowserProfile.attach(browser: self, page: page) }
      end
    end
  end

  Capybara::Playwright::Browser.prepend(CiBrowserProfile::Browser)
  at_exit { CiBrowserProfile.report }
end
