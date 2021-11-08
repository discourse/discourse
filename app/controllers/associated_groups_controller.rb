# frozen_string_literal: true

class AssociatedGroupsController < ApplicationController
  requires_login

  def index
    guardian.ensure_can_associate_groups!
    render_serialized(AssociatedGroup.all, AssociatedGroupSerializer, root: 'associated_groups')
  end
end
