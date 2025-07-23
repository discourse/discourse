# frozen_string_literal: true

class AiChatChannelSerializer < ApplicationSerializer
  attributes :id, :chatable, :chatable_type, :chatable_url, :slug

  def chatable
    case object.chatable_type
    when "Category"
      BasicCategorySerializer.new(object.chatable, root: false).as_json
    when "DirectMessage"
      Chat::DirectMessageSerializer.new(object.chatable, scope: scope, root: false).as_json
    when "Site"
      nil
    end
  end

  def title
    # Display all participants for a DM.
    # For category channels, the argument is ignored.
    object.title(nil)
  end
end
