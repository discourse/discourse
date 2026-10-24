# frozen_string_literal: true

RSpec.describe ReviewablesController do
  fab!(:moderator)
  fab!(:form_template) do
    Fabricate(:form_template, template: [{ id: "description", type: "input" }].as_json.to_yaml)
  end

  describe "#update" do
    it "rejects raw edits to queued forms while allowing metadata edits and approval" do
      submission =
        FormTemplate::Submission.from_template(
          form_template,
          answers: {
            "description" => "A sufficiently long form description.",
          },
        )
      reviewable =
        Fabricate(
          :reviewable_queued_post_topic,
          payload: {
            raw: submission.render,
            form_data: submission.to_h,
            title: "An original form title",
          },
        )
      sign_in(moderator)

      get "/review/#{reviewable.id}.json"
      serialized = response.parsed_body["reviewable"]
      expect(serialized["form_managed"]).to eq(true)
      expect(serialized["editable_fields"].pluck("id")).not_to include("payload.raw")

      put "/review/#{reviewable.id}.json",
          params: {
            version: reviewable.version,
            reviewable: {
              payload: {
                raw: "An inconsistent raw replacement.",
              },
            },
          }
      expect(response.status).to eq(403)
      expect(reviewable.reload.payload["raw"]).to eq(submission.render)

      put "/review/#{reviewable.id}.json",
          params: {
            version: reviewable.version,
            reviewable: {
              payload: {
                title: "A revised form title",
              },
            },
          }
      expect(response.status).to eq(200)
      result = reviewable.reload.perform(moderator, :approve_post)
      expect(result.success?).to eq(true)
      expect(result.created_post.topic.title).to eq("A revised form title")
      expect(result.created_post.form_data).to eq(submission.to_h)
    end
  end
end
