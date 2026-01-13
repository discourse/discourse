# frozen_string_literal: true

module UserStatusMixin
  def self.included(klass)
    klass.attributes :status
  end

  def include_status?
    @options[:include_status] && SiteSetting.enable_user_status &&
      !object.user_option&.hide_profile && object.has_status? &&
      (scope || Guardian.new).can_see_user_status?(object)
  end

  def status
    UserStatusSerializer.new(object.user_status, root: false).as_json
  end
end
