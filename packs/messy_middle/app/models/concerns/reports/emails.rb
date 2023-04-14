# frozen_string_literal: true

module Reports::Emails
  extend ActiveSupport::Concern

  class_methods do
    def report_emails(report)
      report_about report, EmailLog
    end
  end
end
