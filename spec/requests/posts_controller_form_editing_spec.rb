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

  it "rejects NUL in omitted answers on creation and editing, but allows literal escape text" do
    category.form_templates << form_template
    form_template.update!(output_template: "An invitation with omitted answers.")
    invalid_answers = answers.merge("description" => "Omitted\u0000answer")
    params = {
      title: "A form with omitted answers",
      category: category.id,
      form_template_data: { id: form_template.id, answers: invalid_answers }.to_json,
    }

    expect { post "/posts.json", params: }.not_to change(Post, :count)
    expect(response.status).to eq(422)

    literal_answers = answers.merge("description" => 'Omitted\u0000answer')
    params[:form_template_data] = { id: form_template.id, answers: literal_answers }.to_json
    post("/posts.json", params:)
    expect(response.status).to eq(200)
    created = Post.find(response.parsed_body["id"])
    original_data = created.form_data

    put "/posts/#{created.id}.json",
        params: {
          post: {
            form_template_data: { answers: invalid_answers }.to_json,
          },
        }
    expect(response.status).to eq(400)
    expect(created.reload.form_data).to eq(original_data)
    expect(created.form_submission.answers).to eq(literal_answers)
  end

  it "requires complete answers on creation and when repairing an incomplete saved form" do
    category.form_templates << form_template
    form_template.update!(output_template: "A form whose required answer is omitted.")
    incomplete_answers = answers.merge("description" => "")

    expect do
      post "/posts.json",
           params: {
             title: "A form with a missing required answer",
             category: category.id,
             form_template_data: { id: form_template.id, answers: incomplete_answers }.to_json,
           }
    end.not_to change(Post, :count)
    expect(response.status).to eq(422)

    saved = form_post
    incomplete = submission.with_answers(incomplete_answers, validate: false)
    saved.update_columns(raw: incomplete.normalized_raw, form_data: incomplete.to_h)

    put "/posts/#{saved.id}.json",
        params: {
          post: {
            form_template_data: { answers: incomplete_answers }.to_json,
          },
        }
    expect(response.status).to eq(422)
    expect(saved.reload.form_data).to eq(incomplete.to_h)

    put "/posts/#{saved.id}.json",
        params: {
          post: {
            form_template_data: { answers: answers }.to_json,
          },
        }
    expect(response.status).to eq(200)
    expect(saved.reload.form_submission.answers).to eq(answers)
  end

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
        submission.editor_data(guardian: user.guardian).as_json,
      )

      sign_in(Fabricate(:user))
      get "/posts/#{form_post.id}.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body).not_to have_key("form_submission")
    end

    it "omits the form once raw no longer matches the saved answers" do
      form_post.update_columns(raw: "Rewritten outside the form.")
      get "/posts/#{form_post.id}.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body).not_to have_key("form_submission")
    end
  end

  describe "#update" do
    it "allows staff to edit metadata on a soft-deleted form post" do
      form_post.trash!
      sign_in(Fabricate(:admin))

      put "/posts/#{form_post.id}.json",
          params: {
            title: "Updated deleted form title",
            post: {
              raw: form_post.raw,
            },
          }

      expect(response.status).to eq(200)
      expect(form_post.topic.reload.title).to eq("Updated deleted form title")
      expect(form_post.reload.form_submission.answers).to eq(answers)
    end

    it "uses the saved definition after template deletion and detects conflicting edits" do
      original_text = form_post.raw
      form_template.destroy!
      changed = answers.merge("description" => "A revised sufficiently long description.")
      put "/posts/#{form_post.id}.json",
          params: {
            post: {
              form_template_data: { answers: changed }.to_json,
              original_text:,
            },
          }
      expect(response.status).to eq(200)
      expect(form_post.reload.raw).to eq("## Invitation\nA revised sufficiently long description.")
      expect(form_post.form_submission.answers).to eq(changed)

      put "/posts/#{form_post.id}.json",
          params: {
            post: {
              form_template_data: { answers: }.to_json,
              original_text:,
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

    it "detects conflicting edits to answers the output template omits" do
      put "/posts/#{form_post.id}.json",
          params: {
            post: {
              form_template_data: { answers: answers.merge("confirmed" => true) }.to_json,
              original_text: form_post.raw,
              original_form_answers: answers.to_json,
            },
          }
      expect(response.status).to eq(200)
      expect(form_post.reload.form_submission.answers["confirmed"]).to eq(true)

      put "/posts/#{form_post.id}.json",
          params: {
            post: {
              form_template_data: { answers: }.to_json,
              original_text: form_post.raw,
              original_form_answers: answers.to_json,
            },
          }
      expect(response.status).to eq(409)
      expect(form_post.reload.form_submission.answers["confirmed"]).to eq(true)

      put "/posts/#{form_post.id}.json",
          params: {
            post: {
              form_template_data: { answers: }.to_json,
              original_text: form_post.raw,
            },
          }
      expect(response.status).to eq(200)
      expect(form_post.reload.form_submission.answers).to eq(answers)
    end

    it "falls back to markdown editing after a raw-only edit" do
      put "/posts/#{form_post.id}.json",
          params: {
            post: {
              raw: "An unrelated replacement of the form.",
            },
          }
      expect(response.status).to eq(200)
      expect(form_post.reload.raw).to eq("An unrelated replacement of the form.")
      expect(form_post.form_submission).to be_nil

      get "/posts/#{form_post.id}.json"
      expect(response.parsed_body).not_to have_key("form_submission")

      put "/posts/#{form_post.id}.json",
          params: {
            post: {
              form_template_data: { answers: }.to_json,
              original_text: submission.render,
            },
          }
      expect(response.status).to eq(409)

      put "/posts/#{form_post.id}.json",
          params: {
            post: {
              form_template_data: { answers: }.to_json,
            },
          }
      expect(response.status).to eq(200)
      expect(form_post.reload.form_submission.answers).to eq(answers)
    end

    it "rejects structured edits from users who cannot edit the post" do
      sign_in(Fabricate(:user))
      put "/posts/#{form_post.id}.json",
          params: {
            post: {
              form_template_data: { answers: }.to_json,
            },
          }
      expect(response.status).to eq(403)
      expect(form_post.reload.form_submission.answers).to eq(answers)
    end
  end

  describe "#revert" do
    it "restores the saved answers together with the text" do
      changed = submission.with_answers(answers.merge("description" => "A revised description."))
      PostRevisor.new(form_post).revise!(
        user,
        { raw: changed.render, form_data: changed.to_h },
        force_new_version: true,
      )
      expect(form_post.reload.form_submission.answers).to eq(changed.answers)

      sign_in(Fabricate(:admin))
      put "/posts/#{form_post.id}/revisions/2/revert.json"
      expect(response.status).to eq(200)
      expect(form_post.reload.raw).to eq(submission.render)
      expect(form_post.form_submission.answers).to eq(answers)
    end

    it "reverts a change to an answer the output template omits" do
      changed = submission.with_answers(answers.merge("confirmed" => true))
      PostRevisor.new(form_post).revise!(
        user,
        { raw: changed.render, form_data: changed.to_h },
        force_new_version: true,
      )
      expect(form_post.reload.form_submission.answers["confirmed"]).to eq(true)

      sign_in(Fabricate(:admin))
      put "/posts/#{form_post.id}/revisions/2/revert.json"
      expect(response.status).to eq(200)
      expect(form_post.reload.form_submission.answers).to eq(answers)
    end
  end

  describe "form preview" do
    it "allows staff to preview deleted forms while denying other users" do
      form_post.trash!
      params = { post_id: form_post.id, form_template_data: { answers: }.to_json }
      sign_in(Fabricate(:admin))
      post("/form-templates/render.json", params:)
      expect(response.status).to eq(200)
      expect(response.parsed_body["raw"]).to eq(submission.render)

      sign_in(Fabricate(:user))
      post("/form-templates/render.json", params:)
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
