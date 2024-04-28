# frozen_string_literal: true

class GroupUserWithCustomFieldsSerializer < UserWithCustomFieldsSerializer
  include UserPrimaryGroupMixin

  attributes :name, :title, :last_posted_at, :last_seen_at, :added_at, :timezone

  def initialize(object, options = {})
    super
    options[:include_status] = true
  end

  def timezone
    user.user_option.timezone
  end

  def include_added_at?
    object.respond_to? :added_at
  end
end
