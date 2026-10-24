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

  let(:submission) do
    FormTemplate::Submission.from_template(
      form_template,
      answers: {
        "description" => "A sufficiently long description.",
        "confirmed" => false,
      },
    )
  end
  let(:post) do
    Fabricate(:post, post_number: 1, raw: submission.render, form_data: submission.to_h)
  end

  describe "#revert" do
    it "restores matching form state and raw, including answer-only revisions" do
      sign_in(admin)
      [
        submission.answers.merge("description" => "A changed sufficiently long description."),
        submission.answers.merge("confirmed" => true),
      ].each do |answers|
        changed = submission.with_answers(answers)
        PostRevisor.new(post).revise!(
          post.user,
          { raw: changed.render, form_data: changed.to_h },
          force_new_version: true,
        )
        revision = post.revisions.last

        put "/posts/#{post.id}/revisions/#{revision.number}/revert.json"

        expect(response.status).to eq(200)
        expect(post.reload.raw).to eq(submission.render)
        expect(post.form_data).to eq(submission.to_h)
      end
    end
  end

  describe "#revisions" do
    it "excludes form snapshots from public history queries" do
      changed = submission.with_answers(submission.answers.merge("confirmed" => true))
      PostRevisor.new(post).revise!(
        post.user,
        { raw: changed.render, form_data: changed.to_h },
        force_new_version: true,
      )

      %w[2 latest].each do |revision|
        queries = track_sql_queries { get "/posts/#{post.id}/revisions/#{revision}.json" }
        expect(response.status).to eq(200)
        expect(response.parsed_body).not_to have_key("form_answer_changes")
        history_queries = queries.grep(/SELECT .*FROM "post_revisions"/)
        expect(history_queries).not_to be_empty
        history_queries.each do |query|
          expect(query).not_to include('"post_revisions".*', '"form_data_changes"')
        end
      end
    end

    it "shows answer-only changes to editors while respecting hidden revision access" do
      changed = submission.with_answers(submission.answers.merge("confirmed" => true))
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
