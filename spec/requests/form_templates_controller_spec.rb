# frozen_string_literal: true

RSpec.describe FormTemplatesController do
  fab!(:user)

  describe "#index" do
    fab!(:form_template)
    fab!(:form_template_2, :form_template)
    fab!(:form_template_3, :form_template)

    context "when logged in as a user" do
      before { sign_in(user) }

      it "returns all form templates ordered by ID" do
        get "/form-templates.json"
        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["form_templates"]).to be_present
        expect(json["form_templates"].length).to eq(3)

        templates = json["form_templates"].map { |template| template["id"] }
        form_templates = [form_template, form_template_2, form_template_3].sort_by(&:id).map(&:id)

        expect(templates).to eq(form_templates)
      end

      context "with private and public category templates" do
        fab!(:group)
        fab!(:private_category) { Fabricate(:private_category, group: group) }
        fab!(:private_template) do
          Fabricate(
            :form_template,
            name: "Private Template",
            template: "---\n- type: input\n  id: secret\n",
          )
        end
        fab!(:public_category, :category)
        fab!(:public_template) { Fabricate(:form_template, name: "Public Template") }

        before do
          private_category.form_templates << private_template
          public_category.form_templates << public_template
        end

        it "does not return templates only associated with private categories" do
          get "/form-templates.json"
          expect(response.status).to eq(200)
          returned_templates = response.parsed_body["form_templates"]
          returned_ids = returned_templates.map { |t| t["id"] }
          expect(returned_ids).to include(public_template.id)
          expect(returned_ids).not_to include(private_template.id)
          expect(returned_templates.map { |t| t["template"] }).not_to include(
            private_template.template,
          )
        end
      end
    end

    context "when you are not logged in" do
      it "denies access" do
        get "/form-templates.json"
        expect(response.status).to eq(403)
      end
    end

    context "when experimental form templates is disabled" do
      before do
        sign_in(user)
        SiteSetting.enable_form_templates = false
      end

      it "rejects a logged-in user" do
        get "/form-templates.json"
        expect(response.status).to eq(403)
      end
    end
  end

  describe "#show" do
    fab!(:form_template)

    context "when logged in as a user" do
      before { sign_in(user) }

      it "returns one template" do
        get "/form-templates/#{form_template.id}.json"
        expect(response.status).to eq(200)
        json = response.parsed_body
        current_template = json["form_template"]
        expect(current_template["id"]).to eq(form_template.id)
        expect(current_template["name"]).to eq(form_template.name)
        expect(current_template["template"]).to eq(form_template.template)
      end

      context "with a template only in an inaccessible private category" do
        fab!(:group)
        fab!(:private_category) { Fabricate(:private_category, group: group) }
        fab!(:private_template) { Fabricate(:form_template, name: "Secret Template") }

        before { private_category.form_templates << private_template }

        it "returns 404" do
          get "/form-templates/#{private_template.id}.json"
          expect(response.status).to eq(404)
        end
      end

      context "when using tag groups in a form template" do
        fab!(:admin)
        fab!(:tag1) { Fabricate(:tag, description: "A Tag 1 custom Translation") }
        fab!(:tag2) { Fabricate(:tag, description: "A Tag 2 custom Translation") }
        fab!(:tag3, :tag)
        fab!(:tag4, :tag)
        fab!(:tag_synonym) { Fabricate(:tag, name: "discourse") }

        fab!(:tag_group1) { Fabricate(:tag_group, name: "tag_group1", tags: [tag3, tag1]) }
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

        before do
          sign_in(admin)
          #Creates the synonym
          post "/tag/#{tag1.name}/synonyms.json", params: { synonyms: [tag_synonym.name] }
          sign_in(user)
        end

        it "returns one template with the expected data" do
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

          # It excludes synonyms
          expect(parsed_template[0]["choices"].count).to eq(2)

          expect(parsed_template[0]["choices"]).to contain_exactly(
            { "id" => tag1.id, "name" => tag1.name },
            { "id" => tag3.id, "name" => tag3.name },
          )
          expect(parsed_template[1]["choices"]).to contain_exactly(
            { "id" => tag2.id, "name" => tag2.name },
            { "id" => tag4.id, "name" => tag4.name },
          )
        end

        it "returns one template with ordered data" do
          new_tag = Fabricate(:tag, description: "Custom Tag")
          tag_group1.tags = [tag3, tag1, new_tag]
          tag_group1.save

          get "/form-templates/#{tag_groups_form_template.id}.json"
          expect(response.status).to eq(200)
          json = response.parsed_body

          current_template = json["form_template"]
          parsed_template = YAML.safe_load(current_template["template"])
          expect(parsed_template[0]["choices"]).to eq(
            [
              { "id" => tag1.id, "name" => tag1.name },
              { "id" => new_tag.id, "name" => new_tag.name },
              { "id" => tag3.id, "name" => tag3.name },
            ],
          )
        end
      end
    end

    context "when you are not logged in" do
      it "denies access" do
        get "/form-templates/#{form_template.id}.json"
        expect(response.status).to eq(403)
      end
    end

    context "when experimental form templates is disabled" do
      before do
        sign_in(user)
        SiteSetting.enable_form_templates = false
      end

      it "rejects a logged-in user" do
        get "/form-templates/#{form_template.id}.json"
        expect(response.status).to eq(403)
      end
    end
  end

  describe "#render_output" do
    fab!(:render_user) { Fabricate(:user, trust_level: 2) }
    fab!(:category)
    fab!(:render_template) do
      Fabricate(
        :form_template,
        template: [
          {
            id: "description",
            type: "composer",
            attributes: {
              label: "Details",
            },
            validations: {
              required: true,
            },
          },
          {
            id: "seats",
            type: "input",
            attributes: {
              label: "Seats",
            },
            validations: {
              type: "number",
            },
          },
        ].as_json.to_yaml,
      )
    end

    before do
      category.form_templates << render_template
      sign_in(render_user)
    end

    it "renders the default output and preserves original numeric spelling" do
      post "/form-templates/render.json",
           params: {
             category_id: category.id,
             form_template_data: {
               id: render_template.id,
               answers: {
                 description: "**Hello**\n\nWorld",
                 seats: "1e2",
               },
             }.to_json,
           }
      expect(response.status).to eq(200), response.body
      expect(response.parsed_body["raw"]).to eq("### Details\n**Hello**\n\nWorld\n\n### Seats\n1e2")
    end

    it "previews incomplete answers through the same custom renderer" do
      render_template.update!(output_template: "## Invitation\n{{ answers.description }}")
      post "/form-templates/render.json",
           params: {
             category_id: category.id,
             form_template_data: { id: render_template.id, answers: {} }.to_json,
           }
      expect(response.status).to eq(200), response.body
      expect(response.parsed_body["raw"]).to eq("## Invitation\n")
    end

    it "rejects output that exceeds the post length limit" do
      SiteSetting.max_post_length = 10
      render_template.update!(output_template: "{{ answers.description }}")
      post "/form-templates/render.json",
           params: {
             category_id: category.id,
             form_template_data: {
               id: render_template.id,
               answers: {
                 description: "x" * 100,
               },
             }.to_json,
           }
      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to include(I18n.t("form_templates.output_unavailable"))
    end

    it "rejects templates that do not belong to the selected category" do
      post "/form-templates/render.json",
           params: {
             category_id: Fabricate(:category).id,
             form_template_data: { id: render_template.id, answers: {} }.to_json,
           }
      expect(response.status).to eq(404)
    end

    it "rejects inaccessible categories" do
      private_category = Fabricate(:private_category, group: Fabricate(:group))
      private_category.form_templates << render_template
      post "/form-templates/render.json",
           params: {
             category_id: private_category.id,
             form_template_data: { id: render_template.id, answers: {} }.to_json,
           }
      expect(response.status).to eq(403)
    end

    it "rejects malformed payloads and answers that do not match the fields" do
      ["not json", { id: render_template.id, answers: { seats: 1 } }.to_json].each do |payload|
        post "/form-templates/render.json",
             params: {
               category_id: category.id,
               form_template_data: payload,
             }
        expect(response.status).to eq(400)
      end
    end

    it "requires authentication and enabled form templates" do
      SiteSetting.enable_form_templates = false
      post "/form-templates/render.json",
           params: {
             category_id: category.id,
             form_template_data: "{}",
           }
      expect(response.status).to eq(403)
      SiteSetting.enable_form_templates = true
      reset!
      post "/form-templates/render.json",
           params: {
             category_id: category.id,
             form_template_data: "{}",
           }
      expect(response.status).to eq(403)
    end
  end
end
