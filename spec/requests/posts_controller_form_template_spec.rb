# frozen_string_literal: true

RSpec.describe PostsController do
  fab!(:user) { Fabricate(:user, trust_level: 2) }
  fab!(:category)
  fab!(:form_template) do
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
        { id: "confirmed", type: "checkbox", attributes: { label: "Confirmed" } },
      ].as_json.to_yaml,
    )
  end

  before do
    sign_in(user)
    category.form_templates << form_template
  end

  describe "#create" do
    it "renders structured answers on the server instead of trusting raw" do
      post "/posts.json",
           params: {
             title: "A session with structured answers",
             category: category.id,
             raw: "This client body must be ignored",
             form_template_data: {
               id: form_template.id,
               answers: {
                 description: "A sufficiently long **description**.",
                 confirmed: true,
               },
             }.to_json,
           }
      expect(response.status).to eq(200)
      created_post = Post.find(response.parsed_body["id"])
      expect(created_post.raw).to eq(
        "### Details\nA sufficiently long **description**.\n\n### Confirmed\non",
      )
      expect(created_post.cooked).to include("<strong>description</strong>")
    end

    it "uses the configured output template" do
      form_template.update!(output_template: "## Session\n{{ answers.description }}")
      post "/posts.json",
           params: {
             title: "A session with a custom output",
             category: category.id,
             form_template_data: {
               id: form_template.id,
               answers: {
                 description: "A sufficiently long custom description.",
               },
             }.to_json,
           }
      expect(response.status).to eq(200)
      expect(Post.find(response.parsed_body["id"]).raw).to eq(
        "## Session\nA sufficiently long custom description.",
      )
    end

    it "rejects stored unsafe output definitions without creating a post" do
      form_template.update_column(
        :output_template,
        "{{ answers.description | replace: 'x', answers.description }}",
      )
      expect do
        post "/posts.json",
             params: {
               title: "A session with an unsafe stored output template",
               category: category.id,
               form_template_data: {
                 id: form_template.id,
                 answers: {
                   description: "x" * 1000,
                 },
               }.to_json,
             }
      end.not_to change(Post, :count)
      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to include(
        I18n.t("form_templates.errors.invalid_output_template"),
      )
    end

    it "rejects missing required answers even when a client provides raw" do
      expect do
        post "/posts.json",
             params: {
               title: "A session with missing required answers",
               category: category.id,
               raw: "A sufficiently long forged body to bypass validation.",
               form_template_data: { id: form_template.id, answers: {} }.to_json,
             }
      end.not_to change(Post, :count)
      expect(response.status).to eq(422)
    end

    it "runs normal content checks against the server-rendered body" do
      Fabricate(:watched_word, word: "forbiddenword", action: WatchedWord.actions[:block])
      expect do
        post "/posts.json",
             params: {
               title: "A session subject to normal content checks",
               category: category.id,
               raw: "A harmless client supplied body.",
               form_template_data: {
                 id: form_template.id,
                 answers: {
                   description: "A description containing forbiddenword.",
                 },
               }.to_json,
             }
      end.not_to change(Post, :count)
      expect(response.status).to eq(422)
    end

    it "preserves the legacy raw-only creation path" do
      raw = "A sufficiently long body from an older client."
      post "/posts.json",
           params: {
             title: "A session from an older client",
             category: category.id,
             raw:,
           }
      expect(response.status).to eq(200)
      expect(Post.find(response.parsed_body["id"]).raw).to eq(raw)
    end
  end
end
