# frozen_string_literal: true

class EditDirectoryColumnSerializer < DirectoryColumnSerializer
  attributes :enabled,
             :automatic_position

  has_one :user_field, serializer: UserFieldSerializer, embed: :objects
end
