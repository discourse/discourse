class DiscourseAutomationRecurringTrigger < ::Jobs::Scheduled
  def type
    raise 'Overwrite me!'
  end

  def execute(args)
    DiscourseAutomation::Workflow.enqueue_workflows(type)
  end
end
