# frozen_string_literal: true

RSpec.describe FormTemplatesController do
  fab!(:user) { Fabricate(:user) }

  before { SiteSetting.experimental_form_templates = true }

  describe "#index" do
    fab!(:form_template) { Fabricate(:form_template) }
    fab!(:form_template_2) { Fabricate(:form_template) }
    fab!(:form_template_3) { Fabricate(:form_template) }

    context "when logged in as a user" do
      before { sign_in(user) }

      it "should return all form templates ordered by its ids" do
        get "/form-templates.json"
        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["form_templates"]).to be_present
        expect(json["form_templates"].length).to eq(3)

        templates = json["form_templates"].map { |template| template["id"] }
        form_templates = [form_template, form_template_2, form_template_3].sort_by(&:id).map(&:id)

        expect(templates).to eq(form_templates)
      end
    end

    context "when you are not logged in" do
      it "should deny access" do
        get "/form-templates.json"
        expect(response.status).to eq(403)
      end
    end

    context "when experimental form templates is disabled" do
      before do
        sign_in(user)
        SiteSetting.experimental_form_templates = false
      end

      it "should not work if you are a logged in user" do
        get "/form-templates.json"
        expect(response.status).to eq(403)
      end
    end
  end

  describe "#show" do
    fab!(:form_template) { Fabricate(:form_template) }

    context "when logged in as a user" do
      before { sign_in(user) }

      it "should return a single template" do
        get "/form-templates/#{form_template.id}.json"
        expect(response.status).to eq(200)
        json = response.parsed_body
        current_template = json["form_template"]
        expect(current_template["id"]).to eq(form_template.id)
        expect(current_template["name"]).to eq(form_template.name)
        expect(current_template["template"]).to eq(form_template.template)
      end
    end

    context "when you are not logged in" do
      it "should deny access" do
        get "/form-templates/#{form_template.id}.json"
        expect(response.status).to eq(403)
      end
    end

    context "when experimental form templates is disabled" do
      before do
        sign_in(user)
        SiteSetting.experimental_form_templates = false
      end

      it "should not work if you are a logged in user" do
        get "/form-templates/#{form_template.id}.json"
        expect(response.status).to eq(403)
      end
    end
  end
end
