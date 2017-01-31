require_dependency 'wizard/step'
require_dependency 'wizard/field'
require_dependency 'wizard/step_updater'
require_dependency 'wizard/builder'

class Wizard
  attr_reader :steps, :user

  def initialize(user)
    @steps = []
    @user = user
    @first_step = nil
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
      @first_step = step
      step.index = 0
    elsif last_step.present?
      last_step.next = step
      step.previous = last_step
      step.index = last_step.index + 1
    end
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

    first_admin = User.where(admin: true)
                      .where.not(id: Discourse.system_user.id)
                      .joins(:user_auth_tokens)
                      .order('user_auth_tokens.created_at')

    if @user.present? && first_admin.first == @user && (Topic.count < 15)
      !Wizard::Builder.new(@user).build.completed?
    else
      false
    end
  end

  def self.user_requires_completion?(user)
    self.new(user).requires_completion?
  end

end
