# frozen_string_literal: true

class Wizard
  attr_reader :steps, :user
  attr_accessor :max_topics_to_require_completion

  @@excluded_steps = []

  def initialize(user)
    @steps = []
    @user = user
    @first_step = nil
    @max_topics_to_require_completion = 15
  end

  def create_step(step_name)
    Step.new(step_name)
  end

  def append_step(step, after: nil)
    return if @@excluded_steps.include?(step)

    step = create_step(step) if step.is_a?(String)
    yield step if block_given?

    if after
      before_step = @steps.detect { |s| s.id == after }

      if before_step
        step.previous = before_step
        step.index = before_step.index + 1
        if before_step.next
          step.next = before_step.next
          before_step.next.previous = step
        end
        before_step.next = step
        @steps.insert(before_step.index + 1, step)
        step.index += 1 while (step = step.next)
        return
      end
    end

    last_step = @steps.last
    @steps << step

    # If it's the first step
    if @steps.size == 1
      @first_step = step
      step.index = 0
    elsif last_step.present?
      last_step.next = step
      step.previous = last_step
      step.index = last_step.index + 1
    end
  end

  def remove_step(step_id)
    i = @steps.index { |step| step.id == step_id }
    return if i.nil?

    step = @steps.delete_at(i)

    step.previous.next = step.next if step.previous

    while step = step.next
      step.index -= 1
      if step.index == 0
        step.previous = nil
        @first_step = step
      else
        step.previous = @steps[step.index - 1]
      end
    end
  end

  def self.exclude_step(step)
    @@excluded_steps << step
  end

  def steps_with_fields
    @steps_with_fields ||= @steps.select(&:has_fields?)
  end

  def start
    completed =
      UserHistory
        .where(action: UserHistory.actions[:wizard_step], context: steps_with_fields.map(&:id))
        .uniq
        .pluck(:context)

    # First uncompleted step
    steps_with_fields.each { |s| return s if completed.exclude?(s.id) }

    @first_step
  end

  def create_updater(step_id, fields)
    step = @steps.find { |s| s.id == step_id.dasherize }
    Wizard::StepUpdater.new(@user, step, fields)
  end

  def completed?
    completed_steps?(steps_with_fields.map(&:id))
  end

  def completed_steps?(steps)
    steps = [steps].flatten.uniq

    completed =
      UserHistory
        .where(action: UserHistory.actions[:wizard_step], context: steps)
        .distinct
        .order(:context)
        .pluck(:context)

    steps.sort == completed
  end

  def requires_completion?
    return false unless SiteSetting.wizard_enabled?
    return false if SiteSetting.bypass_wizard_check?

    if Topic.limit(@max_topics_to_require_completion + 1).count > @max_topics_to_require_completion
      SiteSetting.bypass_wizard_check = true
      return false
    end

    if @user&.id && User.first_login_admin_id == @user.id
      !Wizard::Builder.new(@user).build.completed?
    else
      false
    end
  end

  def self.user_requires_completion?(user)
    self.new(user).requires_completion?
  end
end
