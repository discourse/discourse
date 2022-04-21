# frozen_string_literal: true

Fabricator(:bookmark) do
  user
  post {
    if !SiteSetting.use_polymorphic_bookmarks
      Fabricate(:post)
    end
  }
  name "This looked interesting"
  reminder_at { 1.day.from_now.iso8601 }
  reminder_set_at { Time.zone.now }
  bookmarkable {
    if SiteSetting.use_polymorphic_bookmarks
      Fabricate(:post)
    end
  }

  # TODO (martin) [POLYBOOK] Not relevant once polymorphic bookmarks are implemented.
  before_create do |bookmark|
    if bookmark.bookmarkable_id.present? || bookmark.bookmarkable.present?
      bookmark.post = nil
      bookmark.post_id = nil
      bookmark.for_topic = false
    end
  end
end

Fabricator(:bookmark_next_business_day_reminder, from: :bookmark) do
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
