# frozen_string_literal: true

class AccessControlList::ValidateModification
  include Service::Base

  params do
    attribute :new_acl, :array
    attribute :target_type, :string

    validates :target_type, presence: true
  end

  policy :target_type_exists
  model :new_acl_with_mandatory, optional: true
  policy :user_will_have_permission

  private

  def target_type_exists(params:)
    Site.access_control_target_classes.map(&:name).include?(params.target_type)
  end

  def fetch_new_acl_with_mandatory(params:)
    AccessControlList.inject_mandatory_acl(params.new_acl, params.target_type)
  end

  def user_will_have_permission(guardian:, new_acl_with_mandatory:)
    new_acl_with_mandatory.any? do |acl|
      if acl[:type].to_s == "group"
        guardian.user.belonging_to_group_ids.include?(acl[:id])
      else
        acl[:id] == guardian.user.id
      end
    end
  end
end
