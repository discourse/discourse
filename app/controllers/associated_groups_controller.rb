# frozen_string_literal: true

class AssociatedGroupsController < ApplicationController
  requires_login
  before_action :ensure_admin

  def index
    render_serialized(AssociatedGroup.all, AssociatedGroupSerializer, root: 'associated_groups')
  end
end
