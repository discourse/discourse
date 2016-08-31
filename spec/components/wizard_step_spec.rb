require 'rails_helper'
require 'wizard'

describe Wizard::Step do

  let(:wizard) { Wizard.new }
  let(:step) { wizard.create_step('test-step') }

  it "supports fields and options" do
    expect(step.fields).to be_empty
    text = step.add_field(id: 'test', type: 'text')
    expect(step.fields).to eq([text])

    dropdown = step.add_field(id: 'snacks', type: 'dropdown')
    dropdown.add_option(id: 'candy')
    dropdown.add_option(id: 'nachos')
    dropdown.add_option(id: 'pizza')

    expect(step.fields).to eq([text, dropdown])
    expect(dropdown.options.size).to eq(3)
  end

end

