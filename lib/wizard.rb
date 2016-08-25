require_dependency 'wizard/step'
require_dependency 'wizard/field'

class Wizard
  attr_reader :start
  attr_reader :steps

  def initialize
    @steps = []
  end

  def create_step(args)
    Step.new(args)
  end

  def append_step(step)
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

  def self.build
    wizard = Wizard.new
    title = wizard.create_step('forum-title')
    title.add_field(id: 'title', type: 'text', required: true, value: SiteSetting.title)
    title.add_field(id: 'site_description', type: 'text', required: true, value: SiteSetting.site_description)
    wizard.append_step(title)

    contact = wizard.create_step('contact')
    contact.add_field(id: 'contact_email', type: 'text', required: true)
    wizard.append_step(contact)

    wizard
  end
end
