require_dependency 'wizard/step'
require_dependency 'wizard/field'

class Wizard
  attr_reader :start, :steps, :user

  def initialize(user)
    @steps = []
    @user = user
  end

  def create_step(step_name)
    Step.new(step_name)
  end

  def append_step(step)
    step = create_step(step) if step.is_a?(String)

    yield step if block_given?

    last_step = @steps.last

    @steps << step

    # If it's the first step
    if @steps.size == 1
      @start = step
      step.index = 0
    elsif last_step.present?
      last_step.next = step
      step.previous = last_step
      step.index = last_step.index + 1
    end
  end

  def create_updater(step_id)
    step = @steps.find {|s| s.id == step_id.dasherize}
    Wizard::StepUpdater.new(@user, step)
  end

end
