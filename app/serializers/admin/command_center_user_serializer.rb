# frozen_string_literal: true

class Admin::CommandCenterUserSerializer < ApplicationSerializer
  attributes :id,
             :username,
             :name,
             :avatar_template,
             :active,
             :admin,
             :moderator,
             :suspended,
             :silenced

  def admin
    object.admin?
  end

  def moderator
    object.moderator?
  end

  def suspended
    object.suspended?
  end

  def silenced
    object.silenced?
  end
end
