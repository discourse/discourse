# frozen_string_literal: true

# Run this script via: bin/rails runner plugins/discourse-calendar/scripts/generate_team_availability_mock_data.rb
#
# This script generates mock data for testing the Team Availability Calendar:
# - ~100 team members distributed globally across different timezones
# - Automated public holidays for 2025 and 2026 based on regions
# - Various leave types (#leave, #sick, #family-reasons, #work, etc.)

require "holidays"

module TeamAvailabilityMockData
  puts "=== Generating Team Availability Mock Data ==="

  # Configuration
  TEAM_SIZE = 100
  LEAVE_PROBABILITY = 0.15 # 15% chance of any given week having a leave event
  SICK_PROBABILITY = 0.05 # 5% chance of sick leave

  # Regions and their timezones
  REGIONS_CONFIG = {
    "us" => {
      timezone: "America/New_York",
      regions: [:us],
      usernames_prefix: "us",
      count: 25,
    },
    "us_west" => {
      timezone: "America/Los_Angeles",
      regions: [:us_ca],
      usernames_prefix: "us_west",
      count: 15,
    },
    "uk" => {
      timezone: "Europe/London",
      regions: [:gb],
      usernames_prefix: "uk",
      count: 15,
    },
    "de" => {
      timezone: "Europe/Berlin",
      regions: [:de],
      usernames_prefix: "de",
      count: 10,
    },
    "fr" => {
      timezone: "Europe/Paris",
      regions: [:fr],
      usernames_prefix: "fr",
      count: 10,
    },
    "au" => {
      timezone: "Australia/Sydney",
      regions: [:au],
      usernames_prefix: "au",
      count: 10,
    },
    "jp" => {
      timezone: "Asia/Tokyo",
      regions: [:jp],
      usernames_prefix: "jp",
      count: 8,
    },
    "br" => {
      timezone: "America/Sao_Paulo",
      regions: [:br],
      usernames_prefix: "br",
      count: 7,
    },
  }

  LEAVE_TYPES = %w[leave sick family-reasons work authorized-absence special-leave parental-leave]

  LEAVE_MESSAGES = {
    "leave" => [
      "Summer vacation",
      "Taking some time off",
      "Annual leave",
      "Holiday break",
      "Personal time off",
      "Vacation time",
      "Rest and recharge",
    ],
    "sick" => ["Not feeling well", "Under the weather", "Doctor's appointment", "Medical leave"],
    "family-reasons" => [
      "Family emergency",
      "Child is sick",
      "Family matters",
      "School event",
      "Family commitment",
    ],
    "work" => [
      "Business trip",
      "Conference attendance",
      "Client meeting",
      "Offsite work",
      "Training session",
    ],
    "authorized-absence" => ["Jury duty", "Voting day", "Legal matter", "Official business"],
    "special-leave" => ["Moving day", "Wedding", "Graduation ceremony", "Special occasion"],
    "parental-leave" => ["New baby", "Parental bonding time", "Paternity leave", "Maternity leave"],
  }

  # Step 1: Create or find the holiday calendar topic
  puts "\n1. Setting up holiday calendar topic..."

  calendar_category =
    Category.find_by(slug: "team-calendar") ||
      Category.create!(
        name: "Team Calendar",
        slug: "team-calendar",
        user: Discourse.system_user,
        color: "0088CC",
        text_color: "FFFFFF",
      )

  admin = User.find_by(admin: true) || Discourse.system_user

  holiday_topic =
    if SiteSetting.holiday_calendar_topic_id.to_i > 0 &&
         Topic.exists?(id: SiteSetting.holiday_calendar_topic_id)
      Topic.find(SiteSetting.holiday_calendar_topic_id)
    else
      post =
        PostCreator.create!(
          admin,
          title: "Team Holiday Calendar 2025-2026",
          raw:
            "[calendar]\n[/calendar]\n\nThis is the team holiday calendar. Post your planned time off here.",
          category: calendar_category.id,
          skip_validations: true,
        )
      SiteSetting.holiday_calendar_topic_id = post.topic_id
      post.topic
    end

  puts "   Holiday topic: #{holiday_topic.title} (ID: #{holiday_topic.id})"

  # Step 2: Create the team group
  puts "\n2. Setting up team group..."

  team_group =
    Group.find_by(name: "global-team") ||
      Group.create!(
        name: "global-team",
        full_name: "Global Team",
        visibility_level: Group.visibility_levels[:members],
      )

  puts "   Team group: #{team_group.name}"

  # Step 3: Create team members
  puts "\n3. Creating team members..."

  created_users = []
  user_index = 1

  REGIONS_CONFIG.each do |region_key, config|
    config[:count].times do |i|
      username = "#{config[:usernames_prefix]}_user_#{i + 1}"

      user =
        User.find_by(username:) ||
          begin
            u =
              User.create!(
                username:,
                email: "#{username}@example.com",
                name: "#{config[:usernames_prefix].upcase} Team Member #{i + 1}",
                password: SecureRandom.hex(16),
                active: true,
                approved: true,
                trust_level: TrustLevel[2],
              )
            u.user_option.update!(timezone: config[:timezone])
            u.custom_fields["holidays-region"] = config[:regions].first.to_s
            u.save_custom_fields
            u
          end

      # Set timezone and holiday region if not already set
      user.user_option.update!(timezone: config[:timezone]) if user.user_option.timezone.blank?
      if user.custom_fields["holidays-region"].blank?
        user.custom_fields["holidays-region"] = config[:regions].first.to_s
        user.save_custom_fields
      end

      team_group.add(user) if team_group.users.exclude?(user)

      created_users << { user:, region_key:, config: }
      user_index += 1
    end

    puts "   Created #{config[:count]} users for #{region_key} (#{config[:timezone]})"
  end

  puts "   Total team members: #{created_users.size}"

  # Step 4: Generate public holidays for 2025-2026
  puts "\n4. Generating public holidays..."

  holiday_count = 0

  created_users.each do |user_data|
    user = user_data[:user]
    regions = user_data[:config][:regions]

    [2025, 2026].each do |year|
      holidays = Holidays.between(Date.new(year, 1, 1), Date.new(year, 12, 31), regions)

      holidays.each do |holiday|
        existing =
          CalendarEvent.find_by(
            topic_id: holiday_topic.id,
            user_id: user.id,
            start_date: holiday[:date],
            post_id: nil,
          )

        next if existing

        CalendarEvent.create!(
          topic_id: holiday_topic.id,
          post_id: nil,
          user_id: user.id,
          description: holiday[:name],
          start_date: holiday[:date],
          end_date: nil,
        )
        holiday_count += 1
      end
    end
  end

  puts "   Created #{holiday_count} public holiday entries"

  # Step 5: Generate leave events
  puts "\n5. Generating leave events..."

  leave_count = 0

  created_users.each do |user_data|
    user = user_data[:user]

    # Generate events for 2025-2026
    [2025, 2026].each do |year|
      # Each user might have 2-6 leave periods per year
      num_leave_periods = rand(2..6)

      num_leave_periods.times do
        leave_type = LEAVE_TYPES.sample
        message_options = LEAVE_MESSAGES[leave_type]
        message = message_options.sample

        # Random start date in the year
        start_date = Date.new(year, rand(1..12), rand(1..28))

        # Duration varies by type
        duration =
          case leave_type
          when "sick"
            rand(1..3)
          when "parental-leave"
            rand(5..20)
          when "leave"
            rand(3..14)
          when "work"
            rand(1..5)
          else
            rand(1..5)
          end

        end_date = start_date + duration.days

        # Check for existing events in this period
        existing =
          CalendarEvent
            .where(topic_id: holiday_topic.id, user_id: user.id)
            .where(
              "start_date <= ? AND (end_date >= ? OR (end_date IS NULL AND start_date >= ?))",
              end_date,
              start_date,
              start_date,
            )
            .exists?

        next if existing

        # Create a post for this leave
        raw = "##{leave_type} #{message}\n\n[date=#{start_date}]"
        raw += " → [date=#{end_date}]" if duration > 1

        begin
          post =
            PostCreator.create!(
              user,
              topic_id: holiday_topic.id,
              raw:,
              skip_validations: true,
              skip_jobs: true,
            )

          CalendarEvent.create!(
            topic_id: holiday_topic.id,
            post_id: post.id,
            user_id: user.id,
            description: "##{leave_type} #{message}",
            start_date:,
            end_date:,
          )
          leave_count += 1
        rescue StandardError => e
          puts "   Warning: Could not create leave for #{user.username}: #{e.message}"
        end
      end
    end
  end

  puts "   Created #{leave_count} leave events"

  # Step 6: Add some current/upcoming events for immediate testing
  puts "\n6. Adding current and upcoming events for immediate testing..."

  current_events = 0
  today = Date.today
  current_week_start = today.beginning_of_week(:monday)

  # Add events for the next 2 weeks for ~30% of users
  created_users
    .sample((created_users.size * 0.3).to_i)
    .each do |user_data|
      user = user_data[:user]

      leave_type = LEAVE_TYPES.sample
      message = LEAVE_MESSAGES[leave_type].sample

      start_offset = rand(0..10)
      start_date = current_week_start + start_offset.days
      duration = rand(1..5)
      end_date = start_date + duration.days

      # Skip if overlaps with existing
      existing =
        CalendarEvent
          .where(topic_id: holiday_topic.id, user_id: user.id)
          .where(
            "start_date <= ? AND (end_date >= ? OR (end_date IS NULL AND start_date >= ?))",
            end_date,
            start_date,
            start_date,
          )
          .exists?

      next if existing

      begin
        raw = "##{leave_type} #{message}\n\n[date=#{start_date}]"
        raw += " → [date=#{end_date}]" if duration > 1

        post =
          PostCreator.create!(
            user,
            topic_id: holiday_topic.id,
            raw:,
            skip_validations: true,
            skip_jobs: true,
          )

        CalendarEvent.create!(
          topic_id: holiday_topic.id,
          post_id: post.id,
          user_id: user.id,
          description: "##{leave_type} #{message}",
          start_date:,
          end_date:,
        )
        current_events += 1
      rescue StandardError => e
        puts "   Warning: Could not create current event for #{user.username}: #{e.message}"
      end
    end

  puts "   Created #{current_events} current/upcoming events"

  # Summary
  puts "\n=== Summary ==="
  puts "Holiday Calendar Topic ID: #{holiday_topic.id}"
  puts "Team Group: #{team_group.name}"
  puts "Total Team Members: #{created_users.size}"
  puts "Public Holidays: #{holiday_count}"
  puts "Leave Events: #{leave_count}"
  puts "Current/Upcoming Events: #{current_events}"
  puts "\nTo test, visit: /availability/#{team_group.name}"
  puts "Or visit: /availability to see all users with events"
end
