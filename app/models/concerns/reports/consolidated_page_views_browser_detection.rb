# frozen_string_literal: true

module Reports::ConsolidatedPageViewsBrowserDetection
  extend ActiveSupport::Concern

  class_methods do
    # NOTE: This report is deprecated, once use_legacy_pageviews is
    # always false or no longer needed we can delete this.
    #
    # The new version of this report is site_traffic.
    def report_consolidated_page_views_browser_detection(report)
      Report.report_site_traffic(report)
    end
  end
end
