# frozen_string_literal: true

RSpec.describe FormTemplateYamlValidator, type: :validator do
  subject(:validator) { described_class.new }

  let(:form_template) { FormTemplate.new(template: yaml_content) }

  describe "#validate" do
    context "with valid YAML" do
      let(:yaml_content) { <<~YAML }
          - type: input
            id: name
            attributes:
              label: "Full name"
              placeholder: "eg. John Smith"
              description: "What is your full name?"
            validations:
              required: true
              minimum: 2
              maximum: 100
        YAML

      it "does not add any errors" do
        validator.validate(form_template)
        expect(form_template.errors).to be_empty
      end
    end

    context "with invalid YAML" do
      let(:yaml_content) { "invalid_yaml_string" }

      it "adds an error message for invalid YAML" do
        validator.validate(form_template)
        expect(form_template.errors[:template]).to include(
          I18n.t("form_templates.errors.invalid_yaml"),
        )
      end
    end
  end

  describe "#check_missing_fields" do
    context "when type field is missing" do
      let(:yaml_content) { <<~YAML }
          - id: name
            attributes:
              label: "Full name"
        YAML

      it "adds an error for missing type field" do
        validator.validate(form_template)
        expect(form_template.errors[:template]).to include(
          I18n.t("form_templates.errors.missing_type"),
        )
      end
    end

    context "when id field is missing" do
      let(:yaml_content) { <<~YAML }
          - type: input
            attributes:
              label: "Full name"
        YAML

      it "adds an error for missing id field" do
        validator.validate(form_template)
        expect(form_template.errors[:template]).to include(
          I18n.t("form_templates.errors.missing_id"),
        )
      end
    end
  end

  describe "#check_allowed_types" do
    context "when YAML has invalid field types" do
      let(:yaml_content) { <<~YAML }
          - type: invalid_type
            id: name
            attributes:
              label: "Full name"
        YAML

      it "adds an error for invalid field types" do
        validator.validate(form_template)
        expect(form_template.errors[:template]).to include(
          I18n.t(
            "form_templates.errors.invalid_type",
            type: "invalid_type",
            valid_types: FormTemplateYamlValidator::ALLOWED_TYPES.join(", "),
          ),
        )
      end
    end

    context "when field type is allowed" do
      let(:yaml_content) { <<~YAML }
          - type: input
            id: name
        YAML

      it "does not add an error for valid field type" do
        validator.validate(form_template)
        expect(form_template.errors[:template]).to be_empty
      end
    end
  end

  describe "#check_descriptions_html" do
    context "when description field has safe HTML" do
      let(:yaml_content) { <<~YAML }
          - type: input
            id: name
            attributes:
              label: "Full name"
              description: "What is your full name? Details <a href='https://test.com'>here</a>."
        YAML

      it "does not add an error" do
        validator.validate(form_template)
        expect(form_template.errors[:template]).to be_empty
      end
    end

    context "when description field has unsafe HTML" do
      let(:yaml_content) { <<~YAML }
          - type: input
            id: name
            attributes:
              label: "Full name"
              description: "What is your full name? Details <script>window.alert('hey');</script>."
        YAML

      it "adds a validation error" do
        validator.validate(form_template)
        expect(form_template.errors[:template]).to include(
          I18n.t("form_templates.errors.unsafe_description"),
        )
      end
    end

    context "when description field has unsafe anchor href" do
      let(:yaml_content) { <<~YAML }
          - type: input
            id: name
            attributes:
              label: "Full name"
              description: "What is your full name? Details <a href='javascript:alert()'>here</a>."
        YAML

      it "adds a validation error" do
        validator.validate(form_template)
        expect(form_template.errors[:template]).to include(
          I18n.t("form_templates.errors.unsafe_description"),
        )
      end
    end
  end

  describe "#check_ids" do
    context "when YAML has duplicate ids" do
      let(:yaml_content) { <<~YAML }
          - type: input
            id: name
          - type: input
            id: name
        YAML

      it "adds an error for duplicate ids" do
        validator.validate(form_template)
        expect(form_template.errors[:template]).to include(
          I18n.t("form_templates.errors.duplicate_ids"),
        )
      end
    end

    context "when YAML has reserved ids" do
      let(:yaml_content) { <<~YAML }
          - type: input
            id: title
        YAML

      it "adds an error for reserved ids" do
        validator.validate(form_template)
        expect(form_template.errors[:template]).to include(
          I18n.t("form_templates.errors.reserved_id", id: "title"),
        )
      end
    end
  end

  describe "#check_tag_groups" do
    fab!(:tag_group)

    context "when tag group names are valid" do
      let(:yaml_content) { <<~YAML }
        - type: tag-chooser
          id: name
          tag_group: "#{tag_group.name}"
        YAML

      it "does not add an error" do
        validator.validate(form_template)
        expect(form_template.errors[:template]).to be_empty
      end
    end

    context "when tag group names contains invalid name" do
      let(:yaml_content) { <<~YAML }
          - type: tag-chooser
            id: name1
            tag_group: "#{tag_group.name}"
          - type: tag-chooser
            id: name2
            tag_group: "invalid tag group name"
        YAML

      it "adds an error for invalid tag groups" do
        validator.validate(form_template)
        expect(form_template.errors[:template]).to include(
          I18n.t(
            "form_templates.errors.invalid_tag_group",
            tag_group_name: "invalid tag group name",
          ),
        )
      end
    end
  end
end
