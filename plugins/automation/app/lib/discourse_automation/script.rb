module DiscourseAutomation
  class Script
    include DiscourseAutomation::ScriptDSL

    attr_reader :automation

    def initialize(automation)
      @automation = automation
    end

    def self.add_script(name, &block)
      define_method("script_#{name}", &block)
    end

    def self.all
      DiscourseAutomation::Script
        .instance_methods(false)
        .grep(/^script_/)
    end
  end
end

DiscourseAutomation::Script.add_script('gift_exchange') do
  placeholders %w[YEAR GIFTER_USERNAME GIFTEE_USERNAME]

  field :giftee_assignment_message, component: :pm, placeholders: true
  field :gift_exchangers_group, component: :group

  version 15

  script do
    now = Time.zone.now

    giftee_assignment_message = automation.metadata_for_field('giftee_assignment_message')
    gift_exchangers_group = automation.metadata_for_field('gift_exchangers_group')

    unless group = Group.find_by(id: gift_exchangers_group['group_id'])
      Rails.logger.warn "[discourse-automation] Couldn’t find group with id #{gift_exchangers_group['group_id']}"
      next
    end

    cf_name = "#{group.name}-exchanged-#{script_version}"
    unless Group.find_by(name: cf_name)
      Group.create!(name: cf_name)
    end

    if group.custom_fields[cf_name].present?
      Rails.logger.warn "[discourse-automation] Gift exchange script has already been run on #{cf_name}"
    end

    usernames = group.users.pluck(:username)

    if usernames.size < 3
      Rails.logger.warn '[discourse-automation] Automation needs at least 3 users in a group'
      next
    end

    usernames.shuffle!
    usernames << usernames[0]

    # shuffle the pairs to prevent prying eyes to identify matches by looking at the timestamps of the topics
    pairs = usernames.each_cons(2).to_a.shuffle

    pairs.each do |gifter, giftee|
      placeholders = {
        'YEAR' => now.year.to_s,
        'GIFTER_USERNAME' => gifter,
        'GIFTEE_USERNAME' => giftee
      }

      raw = utils.apply_placeholders(giftee_assignment_message['body'], placeholders)

      title = utils.apply_placeholders(
        giftee_assignment_message['title'],
        placeholders
      )

      utils.send_pm(
        target_usernames: gifter,
        title: title,
        raw: raw
      )
    end

    group.custom_fields[cf_name] = true
    group.save_custom_fields
  end
end
