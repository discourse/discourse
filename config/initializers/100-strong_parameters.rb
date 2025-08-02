# frozen_string_literal: true

ActiveRecord::Base.public_send(:include, ActiveModel::ForbiddenAttributesProtection)
