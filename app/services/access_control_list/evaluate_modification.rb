# frozen_string_literal: true

class AccessControlList::EvaluateModification
  include Service::Base

  params do
    attribute :new_acl, :array
    attribute :target_id, :integer
    attribute :target_type, :string

    validates :target_type, presence: true
  end

  model :target_type_klass
  model :new_acl_with_mandatory, optional: true
  model :acl_user_will_have, optional: true
  policy :user_will_not_lose_permission
  policy :user_will_have_permission

  private

  def fetch_target_type_klass(params:)
    Site.access_control_target_classes.find { |klass| klass.name == params.target_type }
  end

  def fetch_new_acl_with_mandatory(params:)
    AccessControlList.inject_mandatory_acl(params.new_acl, params.target_type)
  end

  def fetch_acl_user_will_have(guardian:, new_acl_with_mandatory:, params:)
    acl_user_will_have =
      new_acl_with_mandatory.select do |acl|
        if acl[:type].to_s == "group"
          guardian.user.in_any_groups?([acl[:id]])
        else
          acl[:id] == guardian.user.id
        end
      end

    if params.target_id.blank?
      acl_user_will_have << AccessControlList.flat_acl_for(guardian.user, Acl::Permissions::OWNER)
    end

    acl_user_will_have
  end

  def user_will_not_lose_permission(target_type_klass:, acl_user_will_have:)
    return true if !target_type_klass.has_loss_warning_permissions?
    permissions = acl_user_will_have.map { |acl| acl[:permission].to_s }
    return true if permissions.include?(Acl::Permissions::OWNER)

    (target_type_klass.loss_warning_permissions - permissions).empty?
  end

  def user_will_have_permission(acl_user_will_have:)
    acl_user_will_have.any?
  end
end
