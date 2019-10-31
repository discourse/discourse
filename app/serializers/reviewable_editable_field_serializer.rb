# frozen_string_literal: true

class ReviewableEditableFieldSerializer < ApplicationSerializer
  root 'reviewable_editable_field'

  attributes :id, :type
end
