# frozen_string_literal: true

module PageObjects
  module Pages
    module DiscourseWorkflows
      class Credentials < PageObjects::Pages::Base
        def visit_index
          page.visit("/admin/plugins/discourse-workflows/credentials")
          self
        end

        def has_credential?(name)
          page.has_css?("td", text: name)
        end

        def has_no_credentials?
          page.has_css?(".workflows-empty-state")
        end

        def click_add_credential
          if page.has_css?(".workflows-empty-state", wait: 5)
            find(".workflows-empty-state .btn-primary").click
          else
            find(".workflows-admin-table__toolbar .btn-primary").click
          end
          self
        end

        def fill_credential_name(name)
          find(".d-modal input[name='name']").fill_in(with: name)
          self
        end

        def select_credential_type(type)
          find(".d-modal select[name='credential_type']").select(type)
          self
        end

        def fill_credential_field(name, value)
          find(".d-modal input[name='#{name}']").fill_in(with: value)
          self
        end

        def edit_credential(name)
          row = find("tr", text: name)
          row.find("button", text: I18n.t("js.discourse_workflows.edit"), exact_text: true).click
          self
        end

        def has_connection_action?(label)
          page.has_button?(label, class: "workflows-credential-connection__connect")
        end

        def has_connection_status?(status)
          page.has_css?(".workflows-credential-connection__status", text: status)
        end

        def has_masked_client_secret?
          page.has_field?(
            "client_secret",
            with: ::DiscourseWorkflows::Credential::REDACTED_VALUE,
            type: "password",
          )
        end

        def submit_credential_modal
          find(".d-modal .btn-primary[type='submit']").click
          self
        end
      end
    end
  end
end
