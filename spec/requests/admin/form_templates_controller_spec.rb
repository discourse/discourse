# frozen_string_literal: true

RSpec.describe Admin::FormTemplatesController do
  fab!(:admin)
  fab!(:user)
  fab!(:form_template)

  before { SiteSetting.experimental_form_templates = true }

  describe "#index" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "should work if you are an admin" do
        get "/admin/customize/form-templates.json"
        expect(response.status).to eq(200)

        json = response.parsed_body
        expect(json["form_templates"]).to be_present
      end
    end

    context "when logged in as a non-admin user" do
      before { sign_in(user) }

      it "should not work if you are not an admin" do
        get "/admin/customize/form-templates.json"

        expect(response.status).to eq(404)
      end
    end

    context "when experimental form templates is disabled" do
      before do
        sign_in(admin)
        SiteSetting.experimental_form_templates = false
      end

      it "should not work if you are an admin" do
        get "/admin/customize/form-templates.json"

        expect(response.status).to eq(403)
      end
    end
  end

  describe "#show" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "should work if you are an admin" do
        get "/admin/customize/form-templates/#{form_template.id}.json"
        expect(response.status).to eq(200)

        json = response.parsed_body
        current_template = json["form_template"]
        expect(current_template["id"]).to eq(form_template.id)
        expect(current_template["name"]).to eq(form_template.name)
        expect(current_template["template"]).to eq(form_template.template)
      end
    end
  end

  describe "#create" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "creates a form template" do
        expect {
          post "/admin/customize/form-templates.json",
               params: {
                 name: "Bug Reports",
                 template:
                   "- type: input\n  id: website\n  attributes:\n    label: Website or apps\n    description: |\n      Which website or app were you using when the bug happened?\n    placeholder: |\n      e.g. website URL, name of the app\n    validations:\n      required: true",
               }

          expect(response.status).to eq(200)
        }.to change(FormTemplate, :count).by(1)
      end
    end

    context "when logged in as a non-admin user" do
      before { sign_in(user) }

      it "prevents creation with a 404 response" do
        expect do
          post "/admin/customize/form-templates.json",
               params: {
                 name: "Feature Requests",
                 template:
                   " type: checkbox\n  choices:\n    - \"Option 1\"\n    - \"Option 2\"\n    - \"Option 3\"\n  attributes:\n    label: \"Enter question here\"\n    description: \"Enter description here\"\n    validations:\n      required: true\n- type: input\n  attributes:\n    label: \"Enter input label here\"\n    description: \"Enter input description here\"\n    placeholder: \"Enter input placeholder here\"\n    validations:\n      required: true",
               }
        end.not_to change { FormTemplate.count }

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end
  end

  describe "#update" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "updates a form template" do
        put "/admin/customize/form-templates/#{form_template.id}.json",
            params: {
              id: form_template.id,
              name: "Bugs",
              template: "- type: checkbox\n  id: checkbox",
            }

        expect(response.status).to eq(200)
        form_template.reload
        expect(form_template.name).to eq("Bugs")
        expect(form_template.template).to eq("- type: checkbox\n  id: checkbox")
      end
    end

    context "when logged in as a non-admin user" do
      before { sign_in(user) }

      it "prevents update with a 404 response" do
        form_template.reload
        original_name = form_template.name

        put "/admin/customize/form-templates/#{form_template.id}.json",
            params: {
              name: "Updated Template",
              template: "New yaml: true",
            }

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))

        form_template.reload
        expect(form_template.name).to eq(original_name)
      end
    end
  end

  describe "#destroy" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "deletes a form template" do
        expect {
          delete "/admin/customize/form-templates/#{form_template.id}.json"
          expect(response.status).to eq(200)
        }.to change(FormTemplate, :count).by(-1)
      end
    end

    context "when logged in as a non-admin user" do
      before { sign_in(user) }
      it "prevents deletion with a 404 response" do
        expect do
          delete "/admin/customize/form-templates/#{form_template.id}.json"
        end.not_to change { FormTemplate.count }

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end
  end

  describe "#preview" do
    fab!(:tag1, :tag)
    fab!(:tag2, :tag)
    fab!(:tag3, :tag)
    fab!(:tag_group) { Fabricate(:tag_group, tags: [tag1, tag2, tag3]) }
    let!(:form_template_valid) { <<~YAML }
        - type: tag-chooser
          id: tag-chooser
          tag_group: "#{tag_group.name}"
          attributes:
            none_label: "Select an item"
            label: "Enter label here"
            multiple: true
      YAML
    let!(:form_template_invalid) { <<~YAML }
        - type: input
          id: dumplicated
          attributes:
            label: "label"
            placeholder: "placeholder"
        - type: input
          id: dumplicated
          attributes:
            label: "label"
            placeholder: "placeholder"
      YAML

    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "processes a valid template" do
        get "/admin/customize/form-templates/preview.json",
            params: {
              name: "test",
              template: form_template_valid,
            }

        expect(response.status).to eq(200)
        processed_tag_group =
          YAML.safe_load(response.parsed_body["form_template"]["template"]).first
        expect(processed_tag_group["choices"]).to eq([tag1.name, tag2.name, tag3.name].sort)
      end

      it "rejects invalid templates" do
        get "/admin/customize/form-templates/preview.json",
            params: {
              name: "test",
              template: form_template_invalid,
            }

        expect(response.status).to eq(422)
      end
    end
  end
end
