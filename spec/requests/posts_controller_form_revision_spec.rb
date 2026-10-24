# frozen_string_literal: true

RSpec.describe PostsController do
  fab!(:admin)
  fab!(:form_template) do
    Fabricate(
      :form_template,
      template: [
        { id: "description", type: "composer", attributes: { label: "Details" } },
        { id: "confirmed", type: "checkbox" },
      ].as_json.to_yaml,
      output_template: "## Invitation\n{{ answers.description }}",
    )
  end

  describe "#revert" do
    it "restores matching form state and raw, including answer-only revisions" do
      sign_in(admin)
      original =
        FormTemplate::Submission.from_template(
          form_template,
          answers: {
            "description" => "An original sufficiently long description.",
            "confirmed" => false,
          },
        )
      [
        original.answers.merge("description" => "A changed sufficiently long description."),
        original.answers.merge("confirmed" => true),
      ].each do |answers|
        post = Fabricate(:post, post_number: 1, raw: original.render, form_data: original.to_h)
        changed = original.with_answers(answers)
        PostRevisor.new(post).revise!(
          post.user,
          { raw: changed.render, form_data: changed.to_h },
          force_new_version: true,
        )
        revision = post.revisions.last

        put "/posts/#{post.id}/revisions/#{revision.number}/revert.json"

        expect(response.status).to eq(200)
        expect(post.reload.raw).to eq(original.render)
        expect(post.form_data).to eq(original.to_h)
      end
    end

    it "preserves normal staff authorization for restoring form state" do
      original =
        FormTemplate::Submission.from_template(
          form_template,
          answers: {
            "description" => "An original sufficiently long description.",
          },
        )
      post = Fabricate(:post, post_number: 1, raw: original.render, form_data: original.to_h)
      changed = original.with_answers(original.answers.merge("confirmed" => true))
      PostRevisor.new(post).revise!(
        post.user,
        { raw: changed.render, form_data: changed.to_h },
        force_new_version: true,
      )
      sign_in(post.user)

      put "/posts/#{post.id}/revisions/#{post.version}/revert.json"

      expect(response.status).to eq(404)
      expect(post.reload.form_data).to eq(changed.to_h)
    end
  end

  describe "#revisions" do
    it "shows answer-only changes to editors while respecting hidden revision access" do
      original =
        FormTemplate::Submission.from_template(
          form_template,
          answers: {
            "description" => "A sufficiently long description.",
            "confirmed" => false,
          },
        )
      post = Fabricate(:post, post_number: 1, raw: original.render, form_data: original.to_h)
      changed = original.with_answers(original.answers.merge("confirmed" => true))
      PostRevisor.new(post).revise!(
        post.user,
        { raw: changed.render, form_data: changed.to_h },
        force_new_version: true,
      )
      revision = post.revisions.last
      sign_in(post.user)
      get "/posts/#{post.id}/revisions/#{revision.number}.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["form_answer_changes"]).to eq(
        [{ "label" => "confirmed", "previous" => false, "current" => true }],
      )

      revision.hide!
      get "/posts/#{post.id}/revisions/#{revision.number}.json"
      expect(response.parsed_body).not_to have_key("form_answer_changes")
    end
  end
end
