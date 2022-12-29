# frozen_string_literal: true

DiscourseAutomation::Scriptable::GIFT_EXCHANGE = "gift_exchange"

DiscourseAutomation::Scriptable.add(DiscourseAutomation::Scriptable::GIFT_EXCHANGE) do
  placeholder :year
  placeholder :giftee_username
  placeholder :gifter_username

  field :giftee_assignment_messages, component: :pms, accepts_placeholders: true, required: true
  field :gift_exchangers_group, component: :group, required: true

  version 17

  triggerables %i[point_in_time]

  script do |_, fields, automation|
    now = Time.zone.now
    group_id = fields.dig("gift_exchangers_group", "value")

    unless group = Group.find_by(id: group_id)
      Rails.logger.warn "[discourse-automation] Couldn’t find group with id #{group_id}"
      next
    end

    cf_name = "#{group.name}-gifts-were-exchanged-#{automation.id}-#{version}-#{now.year}"
    if group.custom_fields[cf_name].present?
      Rails.logger.warn "[discourse-automation] Gift exchange script has already been run on #{cf_name} this year #{now.year} for this script version #{version}"
      next
    end

    usernames = group.users.pluck(:username)

    if usernames.size < 3
      Rails.logger.warn "[discourse-automation] Gift exchange needs at least 3 users in a group"
      next
    end

    usernames.shuffle!
    usernames << usernames[0]

    # shuffle the pairs to prevent prying eyes to identify matches by looking at the timestamps of the topics
    pairs = usernames.each_cons(2).to_a.shuffle

    pairs.each do |gifter, giftee|
      placeholders = { year: now.year.to_s, gifter_username: gifter, giftee_username: giftee }

      Array(fields.dig("giftee_assignment_messages", "value")).each do |giftee_assignment_message|
        if giftee_assignment_message["title"].blank?
          Rails.logger.warn "[discourse-automation] Gift exchange requires a title for the PM"
          next
        end

        if giftee_assignment_message["raw"].blank?
          Rails.logger.warn "[discourse-automation] Gift exchange requires a raw for the PM"
          next
        end

        raw = utils.apply_placeholders(giftee_assignment_message["raw"], placeholders)
        title = utils.apply_placeholders(giftee_assignment_message["title"], placeholders)

        utils.send_pm(
          { target_usernames: Array(gifter), title: title, raw: raw },
          delay: giftee_assignment_message["delay"],
          encrypt: giftee_assignment_message["encrypt"],
          automation_id: automation.id,
        )
      end
    end

    group.custom_fields[cf_name] = true
    group.save_custom_fields
  end
end
