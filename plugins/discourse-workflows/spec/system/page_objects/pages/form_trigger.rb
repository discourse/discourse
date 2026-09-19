# frozen_string_literal: true

module PageObjects
  module Pages
    module DiscourseWorkflows
      class FormTrigger < PageObjects::Pages::Base
        def visit(uuid)
          page.visit("/workflows/form/#{uuid}")
          self
        end

        def has_workflows_form?
          page.has_css?(".workflows-form")
        end

        def has_form_title?(title)
          page.has_css?(".workflows-form__title", text: title)
        end

        def has_form_field?(name)
          page.has_css?("input[name='#{name}']")
        end

        def fill_field(name, value)
          find("input[name='#{name}']").fill_in(with: value)
          self
        end

        def submit
          find(".workflows-form .btn-primary[type='submit']").click
          self
        end

        def has_completion?
          page.has_css?(".workflows-form__complete")
        end
      end
    end
  end
end
