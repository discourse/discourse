# frozen_string_literal: true

RSpec.describe FormTemplatesController do
  fab!(:user)

  before { SiteSetting.experimental_form_templates = true }

  describe "#index" do
    fab!(:form_template)
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
    fab!(:form_template)

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

      context "when using tag groups in a form template" do
        fab!(:tag1) { Fabricate(:tag, description: "Tag 1 custom Translation") }
        fab!(:tag2) { Fabricate(:tag, description: "Tag 2 custom Translation") }
        fab!(:tag3) { Fabricate(:tag) }
        fab!(:tag4) { Fabricate(:tag) }

        fab!(:tag_group1) { Fabricate(:tag_group, name: "tag_group1", tags: [tag1, tag3]) }
        fab!(:tag_group2) { Fabricate(:tag_group, name: "tag_group2", tags: [tag2, tag4]) }

        fab!(:tag_groups_form_template) do
          Fabricate(
            :form_template,
            name: "TagGroups",
            template:
              %Q(
                - type: tag-chooser
                  id: 1
                  attributes:
                    label: "Full name"
                    description: "What is your full name?"
                    multiple: true
                  tag_group: "tag_group1"  # Replace with actual value if needed
                  validations:
                    required: false

                - type: tag-chooser
                  id: 2
                  attributes:
                    label: "Prescription"
                    description: "Upload your prescription"
                    multiple: false
                  tag_group: "tag_group2"
                  validations:
                    required: true),
          )
        end

        it "should return a single template with the correct data" do
          get "/form-templates/#{tag_groups_form_template.id}.json"
          expect(response.status).to eq(200)
          json = response.parsed_body

          current_template = json["form_template"]
          parsed_template = YAML.safe_load(current_template["template"])

          expect(current_template["id"]).to eq(tag_groups_form_template.id)
          expect(current_template["name"]).to eq(tag_groups_form_template.name)
          expect(current_template["template"]).to eq(YAML.dump(parsed_template))

          expect(parsed_template[0]["attributes"]["tag_group"]).to eq(tag_group1.name)
          expect(parsed_template[1]["attributes"]["tag_group"]).to eq(tag_group2.name)

          expect(parsed_template[0]["attributes"]["tag_choices"]).to eq(
            { tag1.name => tag1.description },
          )
          expect(parsed_template[1]["attributes"]["tag_choices"]).to eq(
            { tag2.name => tag2.description },
          )
          expect(parsed_template[0]["choices"]).to eq([tag1.name, tag3.name])
          expect(parsed_template[1]["choices"]).to eq([tag2.name, tag4.name])
        end
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
