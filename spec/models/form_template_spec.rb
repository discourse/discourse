# frozen_string_literal: true

require "rails_helper"

RSpec.describe FormTemplate, type: :model do
  it "can't have duplicate names" do
    Fabricate(:form_template, name: "Bug Report", template: "some yaml: true")
    t = Fabricate.build(:form_template, name: "Bug Report", template: "some yaml: true")
    expect(t.save).to eq(false)
    t = Fabricate.build(:form_template, name: "Bug Report", template: "some yaml: true")
    expect(t.save).to eq(false)
    expect(described_class.count).to eq(1)
  end

  it "can't have an invalid yaml template" do
    template = "first: good\nsecond; bad"
    t = Fabricate.build(:form_template, name: "Feature Request", template: template)
    expect(t.save).to eq(false)
  end
end
