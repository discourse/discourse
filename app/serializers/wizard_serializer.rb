class WizardSerializer < ApplicationSerializer
  attributes :start

  has_many :steps, serializer: WizardStepSerializer, embed: :objects

  def start
    object.start.id
  end
end
