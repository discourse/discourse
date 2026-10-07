# frozen_string_literal: true

module Acl
  class Permissions
    attr_reader :values

    def initialize(*permissions)
      @values = permissions.map { |permission| permission.to_s.freeze }.uniq.freeze

      @values.each do |permission|
        if !permission.match?(/\A[a-z][a-z0-9_]*\z/) || respond_to?(permission, true)
          raise ArgumentError, "Invalid ACL permission name: #{permission}"
        end

        define_singleton_method(permission) { permission }
      end

      freeze
    end
  end
end
