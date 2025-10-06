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
        3.days.from_now
      elsif Time.zone.now.saturday?
        2.days.from_now
      else
        1.day.from_now
      end
    date.iso8601
  end
  reminder_set_at { Time.zone.now }
end
