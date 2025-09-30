# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminEmailLogs < PageObjects::Pages::AdminBase
      class BaseRow
        attr_reader :element

        def initialize(element)
          @element = element
        end
      end

      class IncomingEmailRow < BaseRow
        def has_subject?(subject)
          element.has_css?(".incoming-email-link", text: subject)
        end

        def has_from_address?(from_address)
          element.has_css?("td:nth-of-type(2)", text: from_address)
        end

        def has_to_address?(to_address)
          element.has_css?("td:nth-of-type(3)", text: to_address)
        end

        def has_error?(error)
          element.has_css?("td:nth-of-type(5)", text: error)
        end
      end

      class EmailLogRow < BaseRow
        def has_user?(username)
          if username.present?
            element.has_css?(".email-logs-user", text: username)
          else
            element.has_no_css?(".email-logs-user")
          end
        end

        def has_to_address?(to_address)
          element.has_css?("td:nth-of-type(3)", text: to_address)
        end

        def has_email_type?(email_type)
          element.has_css?("td:nth-of-type(4)", text: email_type)
        end
      end

      class SentEmailLogRow < EmailLogRow
        def has_reply_key?(reply_key)
          element.has_css?("td:nth-of-type(5) .reply-key", text: reply_key)
        end

        def has_post_description?(description)
          element.has_css?("td:nth-of-type(6)", text: description)
        end

        def has_smtp_response?(response)
          element.has_css?("td:nth-of-type(6) code", text: response)
        end
      end

      class SkippedEmailLogRow < EmailLogRow
        def has_skipped_reason?(reason)
          element.has_css?("td:nth-of-type(5)", text: reason)
        end
      end

      def visit_rejected
        visit_logs(:rejected)
        self
      end

      def visit_received
        visit_logs(:received)
        self
      end

      def visit_bounced
        visit_logs(:bounced)
        self
      end

      def visit_skipped
        visit_logs(:skipped)
        self
      end

      def visit_sent
        visit_logs(:sent)
        self
      end

      def row_for(record)
        element = find("[data-test-email-log-row-id=\"#{record.id}\"]")
        row_class.new(element)
      end

      private

      def row_class
        case @current_log_status
        when :rejected, :received
          IncomingEmailRow
        when :skipped
          SkippedEmailLogRow
        when :sent
          SentEmailLogRow
        else
          EmailLogRow
        end
      end

      def visit_logs(status)
        @current_log_status = status.to_sym
        page.visit("/admin/email-logs/#{@current_log_status == :sent ? nil : status}")
        self
      end
    end
  end
end
