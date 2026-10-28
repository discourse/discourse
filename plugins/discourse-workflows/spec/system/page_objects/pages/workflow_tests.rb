# frozen_string_literal: true

module PageObjects
  module Pages
    module DiscourseWorkflows
      class WorkflowTests < PageObjects::Pages::Base
        def visit_index(workflow_id)
          page.visit("/admin/plugins/discourse-workflows/workflows/#{workflow_id}/tests")
          self
        end

        def visit_editor(workflow_id, test_id)
          page.visit("/admin/plugins/discourse-workflows/workflows/#{workflow_id}/tests/#{test_id}")
          self
        end

        def has_editor_path?(workflow, workflow_test)
          page.has_current_path?(
            "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/tests/#{workflow_test.id}",
          )
        end

        def has_index_path?(workflow)
          page.has_current_path?(
            "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/tests",
          )
        end

        def has_test_row?(workflow_test)
          page.has_css?(".workflows-tests-manager__name", text: workflow_test.name)
        end

        def has_row_state?(workflow_test, state)
          page.has_css?(".workflows-tests-manager tr", text: workflow_test.name) &&
            page.find(".workflows-tests-manager tr", text: workflow_test.name).has_css?(
              ".workflows-test-status.--#{state}",
            )
        end

        def run_row(workflow_test)
          page
            .find(".workflows-tests-manager tr", text: workflow_test.name)
            .find(".workflows-tests-manager__run")
            .click
          self
        end

        def click_preview
          page.find(".workflows-tests-manager__preview-btn").click
          self
        end

        def has_preview_effect?(text)
          page.has_css?(".workflows-tests-manager__preview .workflows-test-editor__effect", text:)
        end

        def save_preview_as_test
          page.find(".workflows-tests-manager__preview .btn-primary").click
          self
        end

        def form
          PageObjects::Components::FormKit.new(".workflows-test-editor")
        end

        def has_name_value?(name)
          form.field("name").has_value?(name)
        end

        def has_check_sentence?(text)
          page.has_css?(".workflows-test-checks__sentence", text:)
        end

        def has_result_state?(state)
          page.has_css?(".workflows-test-editor__results .workflows-test-status.--#{state}") ||
            page.has_css?(".admin-config-area-card__description .workflows-test-status.--#{state}")
        end

        def has_effect?(text)
          page.has_css?(".workflows-test-editor__effect", text:)
        end

        def add_first_effect_as_check
          page.first(".workflows-test-editor__add-check").click
          self
        end

        def run_test
          page.find(".workflows-test-editor__actions .btn-default").click
          self
        end

        def save
          form.submit
          self
        end

        def has_step_needing_response?(name)
          page.has_css?(".workflows-test-editor__node.--needs-response", text: name)
        end

        def has_replayed_step?(name)
          page.find(".workflows-test-editor__node", text: name).has_css?(
            ".workflows-test-editor__node-state",
            text: I18n.t("js.discourse_workflows.tests.editor.replayed_response"),
          )
        end

        def paste_response(name, body)
          node = page.find(".workflows-test-editor__node", text: name)
          node.find(".btn-default").click
          node.find(".workflows-test-editor__paste-input").fill_in(with: body)
          node.find(".workflows-test-editor__paste-actions .btn-primary").click
          self
        end

        def has_banner_tests_state?(state)
          page.has_css?(".workflows-publish-banner__tests.--#{state}")
        end
      end
    end
  end
end
