# frozen_string_literal: true

class WizardSerializer < ApplicationSerializer
  attributes :start, :completed

  has_many :steps, serializer: WizardStepSerializer, embed: :objects

  def start
    object.start.id
  end

  def completed
    object.completed?
  end
end
