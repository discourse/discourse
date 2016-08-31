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
    contact.add_field(id: 'contact_email', type: 'text', required: true, value: SiteSetting.contact_email)
    contact.add_field(id: 'contact_url', type: 'text', value: SiteSetting.contact_url)
    contact.add_field(id: 'site_contact_username', type: 'text', value: SiteSetting.site_contact_username)
    wizard.append_step(contact)

    theme = wizard.create_step('colors')
    scheme = theme.add_field(id: 'color_scheme', type: 'dropdown', required: true)
    scheme.add_option('default')
    scheme.add_option('dark')
    wizard.append_step(theme)

    finished = wizard.create_step('finished')
    wizard.append_step(finished);

    wizard
  end
end
