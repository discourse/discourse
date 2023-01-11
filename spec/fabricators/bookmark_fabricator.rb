# frozen_string_literal: true

Fabricator(:bookmark) do
  user
  name "This looked interesting"
  reminder_at { 1.day.from_now.iso8601 }
  reminder_set_at { Time.zone.now }
  bookmarkable { Fabricate(:post) }
end

Fabricator(:bookmark_next_business_day_reminder, from: :bookmark) do
  reminder_at do
    date =
      if Time.zone.now.friday?
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
