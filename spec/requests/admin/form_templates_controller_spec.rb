# frozen_string_literal: true

RSpec.describe Admin::FormTemplatesController do
  fab!(:admin)
  fab!(:user)
  fab!(:form_template)

  before do
    SiteSetting.experimental_form_templates = true
    SiteSetting.max_form_template_title_length = 100
    SiteSetting.max_form_template_content_length = 3000
  end

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

      it "returns an error if the title is too long" do
        SiteSetting.max_form_template_title_length = 12
        SiteSetting.max_form_template_content_length = 3000

        post "/admin/customize/form-templates.json",
             params: {
               name: "This is a very very long title that is too long for the database",
               template: "- type: input\n  id: name",
             }

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to include(
          I18n.t(
            "form_templates.errors.too_long",
            type: "title",
            max_length: SiteSetting.max_form_template_title_length,
          ),
        )
      end

      it "returns an error if the template content is too long" do
        SiteSetting.max_form_template_title_length = 100
        SiteSetting.max_form_template_content_length = 50

        post "/admin/customize/form-templates.json",
             params: {
               name: "Bug",
               template:
                 "- type: input\n  id: website\n  attributes:\n    label: Website or apps\n    description: |\n      Which website or app were you using when the bug happened, please tell me because I need to know this information?\n    placeholder: |\n      e.g. website URL, name of the app\n    validations:\n      required: true",
             }

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to include(
          I18n.t(
            "form_templates.errors.too_long",
            type: "template",
            max_length: SiteSetting.max_form_template_content_length,
          ),
        )
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
end
