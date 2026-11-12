# frozen_string_literal: true

class GroupUserWithCustomFieldsSerializer < UserWithCustomFieldsSerializer
  include UserPrimaryGroupMixin

  attributes :name, :title, :last_posted_at, :last_seen_at, :added_at

  def initialize(object, options = {})
    super
    options[:include_status] = true
  end

  def include_last_posted_at?
    can_see_profile?
  end

  def include_last_seen_at?
    can_see_profile?
  end

  def include_added_at?
    object.respond_to? :added_at
  end

  private

  def can_see_profile?
    (scope || Guardian.new).can_see_profile?(object)
  end
end
