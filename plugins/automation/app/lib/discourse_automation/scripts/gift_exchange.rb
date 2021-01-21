# frozen_string_literal: true

DiscourseAutomation::Scriptable.add('gift_exchange') do
  placeholder :year
  placeholder :giftee_username
  placeholder :gifter_username

  field :giftee_assignment_message, component: :pm, accepts_placeholders: true
  field :gift_exchangers_group, component: :group

  version 16

  triggerables %i[point_in_time]

  script do |trigger, fields|
    now = Time.zone.now
    giftee_assignment_message = fields['giftee_assignment_message']

    if giftee_assignment_message['title'].blank?
      Rails.logger.warn '[discourse-automation] Gift exchange requires a title for the PM'
      next
    end

    if giftee_assignment_message['body'].blank?
      Rails.logger.warn '[discourse-automation] Gift exchange requires a body for the PM'
      next
    end

    gift_exchangers_group = fields['gift_exchangers_group']

    unless group = Group.find_by(id: gift_exchangers_group['group_id'])
      Rails.logger.warn "[discourse-automation] Couldn’t find group with id #{gift_exchangers_group['group_id']}"
      next
    end

    cf_name = "#{group.name}-gifts-were-exchanged-#{automation.id}-#{version}-#{now.year}"
    if group.custom_fields[cf_name].present?
      Rails.logger.warn "[discourse-automation] Gift exchange script has already been run on #{cf_name} this year #{now.year} for this script version #{version}"
      next
    end

    usernames = group.users.pluck(:username)

    if usernames.size < 3
      Rails.logger.warn '[discourse-automation] Gift exchange needs at least 3 users in a group'
      next
    end

    usernames.shuffle!
    usernames << usernames[0]

    # shuffle the pairs to prevent prying eyes to identify matches by looking at the timestamps of the topics
    pairs = usernames.each_cons(2).to_a.shuffle

    pairs.each do |gifter, giftee|
      placeholders = {
        year: now.year.to_s,
        gifter_username: gifter,
        giftee_username: giftee
      }

      raw = utils.apply_placeholders(giftee_assignment_message['body'], placeholders)

      title = utils.apply_placeholders(
        giftee_assignment_message['title'],
        placeholders
      )

      utils.send_pm(
        target_usernames: Array(gifter),
        title: title,
        raw: raw
      )
    end

    group.custom_fields[cf_name] = true
    group.save_custom_fields
  end
end
