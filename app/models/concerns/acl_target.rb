# frozen_string_literal: true

module AclTarget
  extend ActiveSupport::Concern

  def self.acl_matches?(acl_a, acl_b)
    acl_a[:type].to_sym == acl_b[:type].to_sym && acl_a[:id] == acl_b[:id] &&
      acl_a[:permission].to_s == acl_b[:permission].to_s
  end

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
        mandatory_acl.any? { |mandatory_acl| AclTarget.acl_matches?(acl, mandatory_acl) }
    end
  end
end
