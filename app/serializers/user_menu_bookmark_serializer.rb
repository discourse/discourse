# frozen_string_literal: true

class UserMenuBookmarkSerializer < ApplicationSerializer
  attributes :id, :name, :fancy_title, :topic_id, :bookmarkable_url

  has_one :user, serializer: BasicUserSerializer, embed: :objects

  delegate :fancy_title, :topic_id, :bookmarkable_url, to: :bookmarkable_serializer

  def user
    bookmarkable_serializer.bookmarkable_user
  end

  def include_topic_id?
    bookmarkable_serializer.respond_to?(:topic_id)
  end

  private

  def bookmarkable_serializer
    @bookmarkable_serializer ||=
      object.registered_bookmarkable.serializer.new(
        object,
        scope:,
        root: false,
        link_to_first_unread_post: true,
      )
  end
end
