require 'rails_helper'
require 'wizard'

describe Wizard::Step do

  let(:wizard) { Wizard.new(Fabricate.build(:user)) }
  let(:step) { wizard.create_step('test-step') }

  it "supports fields and options" do
    expect(step.fields).to be_empty
    text = step.add_field(id: 'test', type: 'text')
    expect(step.fields).to eq([text])

    dropdown = step.add_field(id: 'snacks', type: 'dropdown')
    dropdown.add_choice('candy')
    dropdown.add_choice('nachos', data: { color: 'yellow' })
    dropdown.add_choice('pizza', label: 'Pizza!')

    expect(step.fields).to eq([text, dropdown])
    expect(dropdown.choices.size).to eq(3)
  end

end
