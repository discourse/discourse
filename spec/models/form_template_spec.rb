# frozen_string_literal: true

require "rails_helper"

RSpec.describe FormTemplate, type: :model do
  it "can't have duplicate names" do
    Fabricate(:form_template, name: "Bug Report", template: "- type: input\n  id: name")
    t = Fabricate.build(:form_template, name: "Bug Report", template: "- type: input\n  id: name")
    expect(t.save).to eq(false)
    t = Fabricate.build(:form_template, name: "Bug Report", template: "- type: input\n  id: name")
    expect(t.save).to eq(false)
    expect(t.errors.full_messages.first).to include(I18n.t("errors.messages.taken"))
    expect(described_class.count).to eq(1)
  end

  it "can't have an invalid yaml template" do
    template = "- type: checkbox\nattributes; bad"
    t = Fabricate.build(:form_template, name: "Feature Request", template: template)
    expect(t.save).to eq(false)
    expect(t.errors.full_messages.first).to include(I18n.t("form_templates.errors.invalid_yaml"))
  end

  it "must have a supported type" do
    template = "- type: fancy\n  id: something"
    t = Fabricate.build(:form_template, name: "Fancy Template", template: template)
    expect(t.save).to eq(false)
    expect(t.errors.full_messages.first).to include(
      I18n.t(
        "form_templates.errors.invalid_type",
        type: "fancy",
        valid_types: FormTemplateYamlValidator::ALLOWED_TYPES.join(", "),
      ),
    )
  end

  it "must have a type property" do
    template = "- hello: world\n  id: something"
    t = Fabricate.build(:form_template, name: "Basic Template", template: template)
    expect(t.save).to eq(false)
    expect(t.errors.full_messages.first).to include(I18n.t("form_templates.errors.missing_type"))
  end

  it "must have a id property" do
    template = "- type: checkbox"
    t = Fabricate.build(:form_template, name: "Basic Template", template: template)
    expect(t.save).to eq(false)
    expect(t.errors.full_messages.first).to include(I18n.t("form_templates.errors.missing_id"))
  end
end
