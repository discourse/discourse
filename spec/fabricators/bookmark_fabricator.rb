# frozen_string_literal: true

Fabricator(:bookmark) do
  user
  post { Fabricate(:post) }
  topic { |attrs| attrs[:post].topic }
  name "This looked interesting"
  reminder_type { Bookmark.reminder_types[:tomorrow] }
  reminder_at { 1.day.from_now.iso8601 }
  reminder_set_at { Time.zone.now }
end

Fabricator(:bookmark_next_business_day_reminder, from: :bookmark) do
  reminder_type { Bookmark.reminder_types[:next_business_day] }
  reminder_at do
    date = if Time.zone.now.friday?
      Time.zone.now + 3.days
    elsif Time.zone.now.saturday?
      Time.zone.now + 2.days
    else
      Time.zone.now + 1.day
    end
    date.iso8601
  end
  reminder_set_at { Time.zone.now }
end
