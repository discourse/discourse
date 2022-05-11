# frozen_string_literal: true

class UserBookmarkBaseSerializer < ApplicationSerializer
  attributes :id,
             :created_at,
             :updated_at,
             :name,
             :reminder_at,
             :reminder_at_ics_start,
             :reminder_at_ics_end,
             :pinned,
             :title,
             :fancy_title,
             :excerpt,
             :bookmarkable_id,
             :bookmarkable_type,
             :bookmarkable_url

  def title
    raise NotImplementedError
  end

  def fancy_title
    raise NotImplementedError
  end

  def cooked
    raise NotImplementedError
  end

  def bookmarkable_url
    raise NotImplementedError
  end

  def excerpt
    raise NotImplementedError
  end

  def include_reminder_at_ics_start?
    reminder_at.present?
  end

  def include_reminder_at_ics_end?
    reminder_at.present?
  end

  def reminder_at_ics_start
    object.reminder_at_ics
  end

  def reminder_at_ics_end
    object.reminder_at_ics(offset: 1.hour)
  end

  # Note: This assumes that the bookmarkable has a user attached to it,
  # we may need to revisit this assumption at some point.
  has_one :user, serializer: BasicUserSerializer, embed: :objects

  def user
    bookmarkable_user
  end

  private

  def bookmarkable
    object.bookmarkable
  end
end
