# frozen_string_literal: true

class Plugin::Instance
  def add_automation_workflowable(identifier, &block)
    reloadable_patch do
      DiscourseAutomation::Workflowable.add(identifier, &block)
    end
  end

  def add_automation_trigger(identifier, &block)
    reloadable_patch do
      DiscourseAutomation::Triggerable.add(identifier, &block)
    end
  end

  def add_automation_plan(identifier, &block)
    reloadable_patch do
      DiscourseAutomation::Plannable.add(identifier, &block)
    end
  end

  def enqueue_workflows(identifier, args = {})
    reloadable_patch do
      DiscourseAutomation::Workflow.enqueue_workflows(identifier, args)
    end
  end
end
