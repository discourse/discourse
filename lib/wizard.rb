# frozen_string_literal: true

class Wizard

  attr_reader :steps, :user
  attr_accessor :max_topics_to_require_completion

  @@excluded_steps = []
  @@plugin_steps = []

  def initialize(user)
    @steps = []
    @user = user
    @first_step = nil
    @max_topics_to_require_completion = 15
  end

  def create_step(step_name)
    Step.new(step_name)
  end

  def append_step(step)
    return if @@excluded_steps.include?(step)

    step = create_step(step) if step.is_a?(String)

    yield step if block_given?

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

  def append_plugin_steps
    @@plugin_steps.each do |plugin_step|
      step = create_step(plugin_step[:step]) if plugin_step[:step].is_a?(String)
      next if plugin_step[:index] < 1

      plugin_step[:block].call(step)

      existing_step_at_index = @steps[plugin_step[:index]]

      if plugin_step[:index] <= @steps.count - 1
        (plugin_step[:index]..(@steps.count - 1)).each do |index|
          @steps[index].index = @steps[index].index + 1
        end
        previous_step = @steps[plugin_step[:index] - 1]
        previous_step.next = step
        step.previous = previous_step
        step.next = existing_step_at_index
        step.index = plugin_step[:index]
        existing_step_at_index.previous = step
      else
        @steps.last.next = step
        step.previous = @steps.last
      end

      @steps << step
    end
  end

  def self.add_plugin_step(index, step, &block)
    @@plugin_steps << { index: index, step: step, block: block }
  end

  def self.clear_plugin_steps
    @@plugin_steps = []
  end

  def self.exclude_step(step)
    @@excluded_steps << step
  end

  def steps_with_fields
    @steps_with_fields ||= @steps.select(&:has_fields?)
  end

  def start
    completed = UserHistory.where(
      action: UserHistory.actions[:wizard_step],
      context: steps_with_fields.map(&:id)
    ).uniq.pluck(:context)

    # First uncompleted step
    steps_with_fields.each do |s|
      return s unless completed.include?(s.id)
    end

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

    completed = UserHistory.where(
      action: UserHistory.actions[:wizard_step],
      context: steps
    ).distinct.order(:context).pluck(:context)

    steps.sort == completed
  end

  def requires_completion?
    return false unless SiteSetting.wizard_enabled?
    return false if SiteSetting.bypass_wizard_check?

    if Topic.limit(@max_topics_to_require_completion + 1).count > @max_topics_to_require_completion
      SiteSetting.bypass_wizard_check = true
      return false
    end

    first_admin_id = User.where(admin: true)
      .human_users
      .joins(:user_auth_tokens)
      .order('user_auth_tokens.created_at')
      .pluck_first(:id)

    if @user&.id && first_admin_id == @user.id
      !Wizard::Builder.new(@user).build.completed?
    else
      false
    end
  end

  def self.user_requires_completion?(user)
    self.new(user).requires_completion?
  end

end
