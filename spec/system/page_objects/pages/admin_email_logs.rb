# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminEmailLogs < PageObjects::Pages::AdminBase
      class BaseRow
        include NativeSystemHelpers

        attr_reader :element

        def initialize(element)
          @element = element
        end
      end

      class IncomingEmailRow < BaseRow
        def has_subject_link?(subject, href)
          PlaywrightMatchers.have_count(0).does_not_match?(
            element
              .get_by_role("link")
              .and(
                element.locator("[id=#{subject.to_s.to_json}], [name=#{subject.to_s.to_json}]").or(
                  element.get_by_role("link", name: subject),
                ),
              )
              .and(element.locator("[href=#{href.to_s.to_json}]"))
              .filter(visible: true),
          )
        end

        def has_from_address?(from_address)
          PlaywrightMatchers.contain_text(
            [browser_text_pattern(from_address)],
            useInnerText: true,
          ).matches?(element.locator("td:nth-of-type(2)").filter(visible: true))
        end

        def has_to_address?(to_address)
          PlaywrightMatchers.contain_text(
            [browser_text_pattern(to_address)],
            useInnerText: true,
          ).matches?(element.locator("td:nth-of-type(3)").filter(visible: true))
        end

        def has_subject?(subject)
          PlaywrightMatchers.contain_text(
            [browser_text_pattern(subject)],
            useInnerText: true,
          ).matches?(element.locator("td:nth-of-type(4)").filter(visible: true))
        end

        def has_error?(error)
          PlaywrightMatchers.contain_text(
            [browser_text_pattern(error)],
            useInnerText: true,
          ).matches?(element.locator("td:nth-of-type(5)").filter(visible: true))
        end

        def open_incoming_email
          element.locator(".incoming-email-link").filter(visible: true).click
          PageObjects::Modals::AdminIncomingEmailDetailsModal.new
        end
      end

      class EmailLogRow < BaseRow
        def has_user?(username)
          if username.present?
            PlaywrightMatchers.contain_text(
              [browser_text_pattern(username)],
              useInnerText: true,
            ).matches?(element.locator(".email-logs-user").filter(visible: true))
          else
            PlaywrightMatchers.have_count(0).matches?(
              element
                .tap do |parent|
                  parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
                end
                .locator(".email-logs-user")
                .filter(visible: true),
            )
          end
        end

        def has_to_address?(to_address)
          PlaywrightMatchers.contain_text(
            [browser_text_pattern(to_address)],
            useInnerText: true,
          ).matches?(element.locator("td:nth-of-type(3)").filter(visible: true))
        end

        def has_email_type?(email_type)
          PlaywrightMatchers.contain_text(
            [browser_text_pattern(email_type)],
            useInnerText: true,
          ).matches?(element.locator("td:nth-of-type(4)").filter(visible: true))
        end
      end

      class BouncedEmailLogRow < EmailLogRow
        def has_info_button?
          PlaywrightMatchers.have_count(0).does_not_match?(
            element.locator(".email-details a").filter(visible: true),
          )
        end

        def has_no_info_button?
          PlaywrightMatchers.have_count(0).matches?(
            element
              .tap do |parent|
                parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
              end
              .locator(".email-details a")
              .filter(visible: true),
          )
        end

        def open_incoming_email
          element.locator(".email-details a").filter(visible: true).click
          PageObjects::Modals::AdminIncomingEmailDetailsModal.new
        end
      end

      class SentEmailLogRow < EmailLogRow
        def has_reply_key?(reply_key)
          PlaywrightMatchers.contain_text(
            [browser_text_pattern(reply_key)],
            useInnerText: true,
          ).matches?(element.locator("td:nth-of-type(5) .reply-key").filter(visible: true))
        end

        def has_post_description?(description)
          PlaywrightMatchers.contain_text(
            [browser_text_pattern(description)],
            useInnerText: true,
          ).matches?(element.locator("td:nth-of-type(6)").filter(visible: true))
        end

        def has_smtp_response?(response)
          PlaywrightMatchers.contain_text(
            [browser_text_pattern(response)],
            useInnerText: true,
          ).matches?(element.locator("td:nth-of-type(6) code").filter(visible: true))
        end
      end

      class SkippedEmailLogRow < EmailLogRow
        def has_skipped_reason?(reason)
          PlaywrightMatchers.contain_text(
            [browser_text_pattern(reason)],
            useInnerText: true,
          ).matches?(element.locator("td:nth-of-type(5)").filter(visible: true))
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
        element =
          browser_root.locator("[data-test-email-log-row-id=\"#{record.id}\"]").filter(
            visible: true,
          )
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
        when :bounced
          BouncedEmailLogRow
        else
          EmailLogRow
        end
      end

      def visit_logs(status)
        @current_log_status = status.to_sym
        browser_page
          .goto("/admin/email-logs/#{@current_log_status == :sent ? nil : status}")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end
    end
  end
end
