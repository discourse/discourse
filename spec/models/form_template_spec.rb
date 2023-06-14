# frozen_string_literal: true

require "rails_helper"

RSpec.describe FormTemplate, type: :model do
  it "can't have duplicate names" do
    Fabricate(:form_template, name: "Bug Report", template: "- type: input")
    t = Fabricate.build(:form_template, name: "Bug Report", template: "- type: input")
    expect(t.save).to eq(false)
    t = Fabricate.build(:form_template, name: "Bug Report", template: "- type: input")
    expect(t.save).to eq(false)
    expect(described_class.count).to eq(1)
  end

  it "can't have an invalid yaml template" do
    template = "- type: checkbox\nattributes; bad"
    t = Fabricate.build(:form_template, name: "Feature Request", template: template)
    expect(t.save).to eq(false)
  end

  it "must have a supported type" do
    template = "- type: fancy"
    t = Fabricate.build(:form_template, name: "Fancy Template", template: template)
    expect(t.save).to eq(false)
  end

  it "must have a type property" do
    template = "- hello: world"
    t = Fabricate.build(:form_template, name: "Basic Template", template: template)
    expect(t.save).to eq(false)
  end
end
