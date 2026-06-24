# frozen_string_literal: true

module AclTarget
  extend ActiveSupport::Concern

  def self.target_classes
    loaded_target_classes
  end

  def self.loaded_target_classes
    @loaded_target_classes ||= []
  end

  included do
    AclTarget.loaded_target_classes << self if !AclTarget.loaded_target_classes.include?(self)

    has_many :access_control_lists,
             as: :target,
             class_name: "AccessControlList",
             dependent: :destroy

    def reload(options = nil)
      @permission_acl = nil
      super
    end
  end

  def permission_acl
    @permission_acl ||= AccessControlList.where(target: self).target_acl(self)
  end

  def mandatory_acl_as_expanded_list(owner)
    return [] if !self.class.has_mandatory_acl?
    AccessControlList.expand_list(self.class.mandatory_acl, self, owner)
  end

  class_methods do
    def acl_target_key
      name
    end

    def has_mandatory_acl?
      defined?(mandatory_acl).present? && mandatory_acl.length.positive?
    end

    def acl_is_mandatory?(acl)
      has_mandatory_acl? &&
        mandatory_acl.any? do |mandatory_acl|
          mandatory_acl[:type].to_sym == acl[:type] && mandatory_acl[:id] == acl[:id] &&
            mandatory_acl[:permission] == acl[:permission]
        end
    end
  end
end
