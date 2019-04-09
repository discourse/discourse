require_dependency 'admin_user_list_serializer'

class AdminUserSerializer < AdminUserListSerializer

  attributes :name,
             :associated_accounts,
             :can_send_activation_email,
             :can_activate,
             :can_deactivate,
             :can_approve,
             :ip_address,
             :registration_ip_address

  has_one :single_sign_on_record, serializer: SingleSignOnRecordSerializer, embed: :objects

  def can_approve
    reviewable = ReviewableUser.find_by(target: object)
    reviewable.present? && reviewable.actions_for(scope).has?(:approve)
  end

  def include_can_approve?
    SiteSetting.must_approve_users
  end

  def can_send_activation_email
    scope.can_send_activation_email?(object)
  end

  def can_activate
    scope.can_activate?(object)
  end

  def can_deactivate
    scope.can_deactivate?(object)
  end

  def ip_address
    object.ip_address.try(:to_s)
  end

  def registration_ip_address
    object.registration_ip_address.try(:to_s)
  end

end
