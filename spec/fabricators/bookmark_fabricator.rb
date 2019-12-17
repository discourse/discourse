# frozen_string_literal: true

Fabricator(:bookmark) do
  user
  post { Fabricate(:post) }
  topic nil
  name "This looked interesting"
  reminder_type { Bookmark.reminder_types[:tomorrow] }
  reminder_at { (Time.now.utc + 1.day).iso8601 }
end

Fabricator(:bookmark_next_business_day_reminder, from: :bookmark) do
  reminder_type { Bookmark.reminder_types[:next_business_day] }
  reminder_at do
    date = if Time.now.utc.friday?
      Time.now.utc + 3.days
    elsif Time.now.utc.saturday?
      Time.now.utc + 2.days
    else
      Time.now.utc + 1.day
    end
    date.iso8601
  end
end
