# frozen_string_literal: true

module PageObjects
  module Pages
    module DiscourseWorkflows
      class Variables < PageObjects::Pages::Base
        def visit_index
          page.visit("/admin/plugins/discourse-workflows/variables")
          self
        end

        def has_variable?(key)
          page.has_css?("td", text: key)
        end

        def has_variable_creator?(username)
          page.has_css?(".workflows-variables__creator[href$='/u/#{username}']", text: username)
        end

        def has_no_variables?
          page.has_css?(".workflows-empty-state")
        end

        def click_add_variable
          if page.has_css?(".workflows-empty-state", wait: 5)
            find(".workflows-empty-state .btn-primary").click
          else
            find(".workflows-admin-table__toolbar .btn-primary").click
          end
          self
        end

        def fill_variable_key(key)
          find(".d-modal input[name='key']").fill_in(with: key)
          self
        end

        def fill_variable_value(value)
          find(".d-modal input[name='value']").fill_in(with: value)
          self
        end

        def submit_variable_modal
          find(".d-modal .btn-primary[type='submit']").click
          self
        end
      end
    end
  end
end
