require 'rails_helper'
require 'wizard'

describe Wizard do

  let(:user) { Fabricate.build(:user) }
  let(:wizard) { Wizard.new(user) }

  it "has default values" do
    expect(wizard.start).to be_blank
    expect(wizard.steps).to be_empty
    expect(wizard.user).to be_present
  end

  describe "append_step" do

    let(:step1) { wizard.create_step('first-step') }
    let(:step2) { wizard.create_step('second-step') }

    it "works with a block format" do
      wizard.append_step('wat') do |step|
        expect(step).to be_present
      end

      expect(wizard.steps.size).to eq(1)
    end

    it "adds the step correctly" do
      expect(step1.index).to be_blank

      wizard.append_step(step1)
      expect(wizard.steps.size).to eq(1)
      expect(wizard.start).to eq(step1)
      expect(step1.next).to be_blank
      expect(step1.previous).to be_blank
      expect(step1.index).to eq(0)

      expect(step1.fields).to be_empty
      field = step1.add_field(id: 'test', type: 'text')
      expect(step1.fields).to eq([field])
    end

    it "sequences multiple steps" do
      wizard.append_step(step1)
      wizard.append_step(step2)

      expect(wizard.steps.size).to eq(2)
      expect(wizard.start).to eq(step1)
      expect(step1.next).to eq(step2)
      expect(step1.previous).to be_blank
      expect(step2.previous).to eq(step1)
      expect(step1.index).to eq(0)
      expect(step2.index).to eq(1)
    end
  end

end
