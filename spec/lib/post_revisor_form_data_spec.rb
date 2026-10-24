# frozen_string_literal: true

RSpec.describe PostRevisor do
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

  describe "#revise!" do
    it "rejects a stale instance after an answer-only grace edit" do
      stale = Post.find(post.id)
      changed = submission.with_answers(submission.answers.merge("confirmed" => true))
      expect(
        described_class.new(post).revise!(
          post.user,
          { raw: changed.render, form_data: changed.to_h },
        ),
      ).to eq(true)

      replacement =
        submission.with_answers(
          submission.answers.merge("description" => "A stale replacement of the description."),
        )
      expect(
        described_class.new(stale).revise!(
          stale.user,
          { raw: replacement.render, form_data: replacement.to_h },
        ),
      ).to eq(false)
      expect(stale.errors.of_kind?(:base, :edit_conflict)).to eq(true)
      expect(post.reload.form_data).to eq(changed.to_h)
    end

    it "revisions answer-only edits and exposes them to the existing post edit event" do
      changed = submission.with_answers(submission.answers.merge("confirmed" => true))
      events =
        DiscourseEvent.track_events do
          expect(
            described_class.new(post).revise!(
              post.user,
              { form_data: changed.to_h, raw: changed.render },
              force_new_version: true,
            ),
          ).to eq(true)
        end
      expect(post.reload.raw).to eq(submission.render)
      expect(post.form_submission.answers["confirmed"]).to eq(true)
      expect(post.revisions.last.modifications["form_data"]).to eq([submission.to_h, changed.to_h])
      expect(events.map { |event| event[:event_name] }).to include(:post_edited)
      post.revert_to(1)
      expect(post.form_data).to eq(submission.to_h)
      expect(post.raw).to eq(submission.render)
    end

    it "preserves the original raw and answers across initial grace edits" do
      SiteSetting.editing_grace_period = 60
      original_post = post
      original_post.update_columns(last_editor_id: post.user_id)
      first =
        submission.with_answers(
          submission.answers.merge("description" => "A changed sufficiently long description."),
        )
      second = first.with_answers(first.answers.merge("confirmed" => true))

      expect(
        described_class.new(post).revise!(
          post.user,
          { form_data: first.to_h, raw: first.render },
          revised_at: post.updated_at + 1.second,
        ),
      ).to eq(true)
      expect(post.reload.version).to eq(1)
      expect(
        described_class.new(post).revise!(
          post.user,
          { form_data: second.to_h, raw: second.render },
          force_new_version: true,
        ),
      ).to eq(true)
      revision = post.reload.revisions.last
      expect(revision.modifications["form_data"]).to eq([submission.to_h, second.to_h])
      expect(revision.modifications["raw"]).to eq([submission.render, second.render])
    end

    it "coalesces subsequent grace edits into the existing form revision" do
      SiteSetting.editing_grace_period = 60
      first =
        submission.with_answers(
          submission.answers.merge("description" => "First changed sufficiently long description."),
        )
      second = first.with_answers(first.answers.merge("confirmed" => true))
      described_class.new(post).revise!(
        post.user,
        { form_data: first.to_h, raw: first.render },
        force_new_version: true,
      )
      described_class.new(post).revise!(
        post.user,
        { form_data: second.to_h, raw: second.render },
        revised_at: post.updated_at + 1.second,
      )
      expect(post.reload.revisions.count).to eq(1)
      expect(post.revisions.last.modifications["form_data"]).to eq([submission.to_h, second.to_h])
    end

    it "keeps form state on first posts only" do
      reply =
        Fabricate.build(
          :post,
          topic: post.topic,
          post_number: 2,
          raw: submission.render,
          form_data: submission.to_h,
        )
      expect(reply).not_to be_valid
      expect(reply.errors[:form_data]).to be_present
    end

    it "rejects mismatched raw edits without persisting either state" do
      expect(
        described_class.new(post).revise!(
          post.user,
          { raw: "An unrelated replacement of the body." },
        ),
      ).to eq(false)
      expect(post.reload.raw).to eq(submission.render)
      expect(post.form_data).to eq(submission.to_h)
      expect(post.revisions.count).to eq(0)
    end
  end
end
