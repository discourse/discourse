# frozen_string_literal: true

describe "enable_discourse_workflows site setting hook" do
  fab!(:workflow) { Fabricate(:discourse_workflows_workflow, published: true) }
  fab!(:execution) do
    Fabricate(
      :discourse_workflows_execution,
      workflow: workflow,
      status: :waiting,
      waiting_until: 1.minute.ago,
    )
  end

  it "reschedules waiting executions when the setting flips false to true" do
    SiteSetting.enable_discourse_workflows = false

    expect_enqueued_with(
      job: Jobs::DiscourseWorkflows::ResumeWaitingExecution,
      args: {
        execution_id: execution.id,
      },
    ) { SiteSetting.enable_discourse_workflows = true }
  end

  it "does not reschedule when the setting flips true to false" do
    SiteSetting.enable_discourse_workflows = true

    expect_not_enqueued_with(
      job: Jobs::DiscourseWorkflows::ResumeWaitingExecution,
      args: {
        execution_id: execution.id,
      },
    ) { SiteSetting.enable_discourse_workflows = false }
  end

  it "does not reschedule for unrelated setting changes" do
    SiteSetting.enable_discourse_workflows = true

    expect_not_enqueued_with(
      job: Jobs::DiscourseWorkflows::ResumeWaitingExecution,
      args: {
        execution_id: execution.id,
      },
    ) { SiteSetting.title = "Different title" }
  end

  describe "when the upcoming change is automatically promoted" do
    # Promotion leaves no override in the database, so :site_setting_changed never
    # fires. The setting reads as enabled purely because the change has reached
    # promote_upcoming_changes_on_status.
    before do
      SiteSetting.remove_override!(:enable_discourse_workflows)
      SiteSetting.promote_upcoming_changes_on_status = :experimental
    end

    after { SiteSetting.promote_upcoming_changes_on_status = :beta }

    it "reschedules waiting executions" do
      expect_enqueued_with(
        job: Jobs::DiscourseWorkflows::ResumeWaitingExecution,
        args: {
          execution_id: execution.id,
        },
      ) { DiscourseEvent.trigger(:upcoming_change_enabled, :enable_discourse_workflows) }
    end

    it "does nothing for an unrelated upcoming change" do
      DiscourseWorkflows::PluginEnableHandler.expects(:handle!).never

      DiscourseEvent.trigger(:upcoming_change_enabled, :enable_upload_debug_mode)
    end
  end

  describe "when an admin manually opts in to the upcoming change" do
    fab!(:admin)

    before { SiteSetting.remove_override!(:enable_discourse_workflows) }

    it "handles the enable exactly once" do
      # Toggle writes the setting (firing :site_setting_changed) and then fires
      # :upcoming_change_enabled, so the handler must not run twice.
      DiscourseWorkflows::PluginEnableHandler.expects(:handle!).once

      UpcomingChanges::Toggle.call(
        params: {
          setting_name: :enable_discourse_workflows,
          enabled: true,
        },
        guardian: admin.guardian,
      )
    end
  end
end
