# frozen_string_literal: true

RSpec.describe PostsController do
  fab!(:user) { Fabricate(:user, trust_level: 2) }
  fab!(:category)
  fab!(:form_template) do
    Fabricate(
      :form_template,
      template: [
        { id: "description", type: "input", validations: { required: true } },
        { id: "confirmed", type: "checkbox" },
      ].as_json.to_yaml,
      output_template: "## Invitation\n{{ answers.description }}",
    )
  end
  let(:answers) { { "description" => "A sufficiently long description.", "confirmed" => false } }
  let(:submission) { FormTemplate::Submission.from_template(form_template, answers:) }
  let(:form_post) do
    Fabricate(:post, user:, raw: submission.render, form_data: submission.to_h, post_number: 1)
  end

  before { sign_in(user) }

  describe "#create" do
    it "preserves form state through queued approval" do
      category.form_templates << form_template
      category.update!(require_topic_approval: true)
      post "/posts.json",
           params: {
             title: "A form awaiting approval",
             category: category.id,
             form_template_data: { id: form_template.id, answers: }.to_json,
           }
      expect(response.status).to eq(200)
      reviewable = ReviewableQueuedPost.last
      expect(reviewable.payload["form_data"]).to eq(submission.to_h)
      result = reviewable.perform(Fabricate(:admin), :approve_post)
      expect(result.success?).to eq(true)
      expect(result.created_post.form_data).to eq(submission.to_h)
    end

    it "persists the server definition and typed answers" do
      category.form_templates << form_template
      post "/posts.json",
           params: {
             title: "A topic with a saved form",
             category: category.id,
             form_template_data: { id: form_template.id, answers:, definition: {} }.to_json,
           }

      expect(response.status).to eq(200)
      created = Post.find(response.parsed_body["id"])
      expect(created.form_data).to eq(submission.to_h)
    end
  end

  describe "#show" do
    it "exposes editable state only to an authorized editor" do
      get "/posts/#{form_post.id}.json"
      expect(response.parsed_body["form_submission"]).to eq(
        submission.editor_data(raw: form_post.raw, guardian: user.guardian).as_json,
      )

      sign_in(Fabricate(:user))
      get "/posts/#{form_post.id}.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body).not_to have_key("form_submission")
    end
  end

  describe "#update" do
    it "reopens and edits a system-expanded snapshot without allowing further growth" do
      form_template.update!(
        template: (form_template.fields + [{ "id" => "note", "type" => "composer" }]).to_yaml,
      )
      data = submission.to_h
      data["answers"]["note"] = "old "
      data["answers"]["note"] += "x" *
        (FormTemplate::Submission::MAX_BYTES - JSON.generate(data).bytesize)
      expanded =
        FormTemplate::Submission
          .new(data)
          .rewrite_text { |text| text.gsub("old ", "longer " * 200) }
      form_post.update!(raw: expanded.render, form_data: expanded.to_h)

      get "/posts/#{form_post.id}.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body.dig("form_submission", "answers")).to eq(expanded.answers)
      edited_answers = expanded.answers.merge("confirmed" => true)
      payload = { answers: edited_answers }.to_json
      expect(payload.bytesize).to be > FormTemplate::Submission::MAX_BYTES

      put "/posts/#{form_post.id}.json", params: { post: { form_template_data: payload } }
      expect(response.status).to eq(200)
      expect(form_post.reload.form_submission.answers).to eq(edited_answers)

      edited_answers["note"] += "More text"
      put "/posts/#{form_post.id}.json",
          params: {
            post: {
              form_template_data: { answers: edited_answers }.to_json,
            },
          }
      expect(response.status).to eq(400)
      expect(form_post.reload.form_submission.answers["note"]).to eq(expanded.answers["note"])
    end

    it "preserves username rewrites when editing another answer" do
      Jobs.run_immediately!
      UserActionManager.enable
      SiteSetting.allow_uppercase_posts = true
      mentioned = Fabricate(:user, username: "formfriend")
      form_template.update!(
        output_template:
          "{% if answers.description %}{{ answers.description | upcase }}{% endif %}",
      )
      original =
        submission.with_answers(
          answers.merge("description" => "Playing with @formfriend this evening."),
        )
      saved = create_post(user:, raw: original.render, form_data: original.to_h)
      changed =
        original.with_answers(
          original.answers.merge("description" => "Playing with @formfriend tomorrow evening."),
        )
      PostRevisor.new(saved).revise!(
        user,
        { raw: changed.render, form_data: changed.to_h },
        force_new_version: true,
      )
      toggled = changed.with_answers(changed.answers.merge("confirmed" => true))
      PostRevisor.new(saved).revise!(
        user,
        { raw: toggled.render, form_data: toggled.to_h },
        force_new_version: true,
      )

      expect(UsernameChanger.new(mentioned, "renamedfriend").change(asynchronous: false)).to eq(
        true,
      )
      saved.reload
      expect(saved.form_submission.render).to eq(saved.raw)
      expect(saved.raw).to include("@RENAMEDFRIEND")
      saved.revisions.each do |revision|
        expect(revision.form_data_changes.map { |data| data.dig("answers", "description") }).to all(
          include("@renamedfriend"),
        )
      end

      put "/posts/#{saved.id}.json",
          params: {
            post: {
              form_template_data: {
                answers: saved.form_submission.answers.merge("confirmed" => false),
              }.to_json,
              form_state_token: saved.form_state_token,
            },
          }
      expect(response.status).to eq(200), response.body
      expect(saved.reload.raw).to include("@RENAMEDFRIEND")
      expect(saved.form_submission.answers["confirmed"]).to eq(false)
    end

    it "uses the saved definition after template deletion and rejects stale answer-only edits" do
      token = form_post.form_state_token
      form_template.destroy!
      changed = answers.merge("confirmed" => true)
      put "/posts/#{form_post.id}.json",
          params: {
            post: {
              form_template_data: { answers: changed }.to_json,
              form_state_token: token,
            },
          }
      expect(response.status).to eq(200), response.body
      expect(form_post.reload.raw).to eq(submission.render)
      expect(form_post.form_submission.answers).to eq(changed)

      put "/posts/#{form_post.id}.json",
          params: {
            post: {
              form_template_data: { answers: }.to_json,
              form_state_token: token,
            },
          }
      expect(response.status).to eq(409)
      expect(form_post.reload.form_submission.answers).to eq(changed)

      put "/posts/#{form_post.id}.json",
          params: {
            post: {
              form_template_data: { answers: }.to_json,
            },
          }
      expect(response.status).to eq(200)
      expect(form_post.reload.form_submission.answers).to eq(answers)
    end

    it "rejects raw-only writes and unauthorized structured writes" do
      original = form_post.form_data
      put "/posts/#{form_post.id}.json",
          params: {
            post: {
              raw: "An unrelated replacement of the form.",
            },
          }
      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to include(
        I18n.t("form_templates.raw_managed_by_form"),
      )
      expect(form_post.reload.form_data).to eq(original)
      expect(form_post.raw).to eq(submission.render)
      expect(form_post.revisions.count).to eq(0)

      sign_in(Fabricate(:user))
      put "/posts/#{form_post.id}.json",
          params: {
            post: {
              form_template_data: { answers: }.to_json,
              form_state_token: form_post.form_state_token,
            },
          }
      expect(response.status).to eq(403)
      expect(form_post.reload.form_data).to eq(original)
    end
  end

  describe "form preview" do
    it "rejects previews by users who cannot edit the form" do
      sign_in(Fabricate(:user))
      post "/form-templates/render.json",
           params: {
             post_id: form_post.id,
             form_template_data: { answers: }.to_json,
           }
      expect(response.status).to eq(403)
    end

    it "previews incomplete edits without changing saved state, even after forms are disabled" do
      original = form_post.form_data
      SiteSetting.enable_form_templates = false
      post "/form-templates/render.json",
           params: {
             post_id: form_post.id,
             form_template_data: { answers: { description: "" } }.to_json,
           }
      expect(response.status).to eq(200)
      expect(response.parsed_body["raw"]).to eq("## Invitation\n")
      expect(form_post.reload.form_data).to eq(original)
    end
  end
end
