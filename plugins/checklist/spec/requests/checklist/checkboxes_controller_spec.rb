# frozen_string_literal: true

RSpec.describe Checklist::CheckboxesController do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:topic) { Fabricate(:topic, user: user) }

  fab!(:post) { Fabricate(:post, topic: topic, user: user, raw: "- [ ] first\n- [x] second") }

  before { SiteSetting.checklist_enabled = true }

  describe "#toggle" do
    let(:toggle) { { checkbox_index: 0, checkbox_source: "0:0", checked: true } }
    let(:params) do
      {
        post_id: post.id,
        toggles: [toggle],
        expected_raw: post.raw,
        expected_updated_at: post.updated_at.iso8601(3),
        mutation_id: "mutation-123",
      }
    end

    context "when not logged in" do
      it "returns a 403" do
        put "/checklist/toggle.json", params: params

        expect(response.status).to eq(403)
      end
    end

    context "when logged in as the post author" do
      before { sign_in(user) }

      it "toggles the checkbox" do
        put "/checklist/toggle.json", params: params

        expect(response.status).to eq(200)
        post.reload
        expect(response.parsed_body).to include(
          "cooked" => post.cooked,
          "raw" => "- [x] first\n- [x] second",
          "revised" => true,
          "updated_at" => post.updated_at.iso8601(3),
        )
        expect(post.raw).to eq("- [x] first\n- [x] second")
      end

      it "succeeds without changes when the state already matches" do
        expect {
          put "/checklist/toggle.json",
              params: params.merge(toggles: [toggle.merge(checked: false)])
        }.not_to change { post.reload.raw }

        expect(response.status).to eq(200)
        expect(response.parsed_body["revised"]).to eq(false)
      end

      it "returns a 400 when params are missing" do
        put "/checklist/toggle.json", params: { post_id: post.id }

        expect(response.status).to eq(400)
        expect(response.parsed_body["errors"]).to be_present
      end

      it "returns a 400 when params are invalid" do
        put "/checklist/toggle.json",
            params: params.merge(toggles: [toggle.merge(checkbox_index: -1)])

        expect(response.status).to eq(400)
        expect(response.parsed_body["errors"]).to be_present
      end

      it "returns a 404 when the post does not exist" do
        put "/checklist/toggle.json", params: params.merge(post_id: -1)

        expect(response.status).to eq(404)
      end

      it "returns a retryable 409 after checklist-only changes" do
        PostRevisor.new(post).revise!(
          user,
          { raw: "- [x] first\n- [x] second" },
          force_new_version: true,
        )
        expected_updated_at = post.reload.updated_at.iso8601(3)
        expected_raw = post.raw
        freeze_time(1.second.from_now) do
          PostRevisor.new(post).revise!(user, { raw: "- [x] first\n- [ ] second" })
        end
        expect(post.reload.revisions.one?).to eq(true)

        put "/checklist/toggle.json", params: params.merge(expected_raw:, expected_updated_at:)

        expect(response.status).to eq(409)
        expect(response.parsed_body).to include(
          "errors" => [I18n.t("checklist.checkboxes_changed")],
          "updated_at" => post.reload.updated_at.iso8601(3),
          "retryable" => true,
        )
      end

      it "returns a retryable 409 for checklist-only grace-period edits" do
        expected_updated_at = post.updated_at.iso8601(3)
        expected_raw = post.raw
        freeze_time(1.second.from_now) do
          PostRevisor.new(post).revise!(user, { raw: "- [x] first\n- [x] second" })
        end
        expect(post.reload.revisions).to be_empty

        put "/checklist/toggle.json", params: params.merge(expected_raw:, expected_updated_at:)

        expect(response.status).to eq(409)
        expect(response.parsed_body).to include(
          "raw" => post.raw,
          "retryable" => true,
          "updated_at" => post.updated_at.iso8601(3),
        )
      end

      it "returns a non-retryable 409 after other post changes" do
        SiteSetting.post_edit_time_limit = 0
        post.update_columns(created_at: 1.day.ago, updated_at: 1.day.ago)
        expected_updated_at = post.reload.updated_at.iso8601(3)
        expected_raw = post.raw
        PostRevisor.new(post).revise!(user, { raw: "intro\n#{post.raw}" }, force_new_version: true)

        put "/checklist/toggle.json", params: params.merge(expected_raw:, expected_updated_at:)

        expect(response.status).to eq(409)
        expect(response.parsed_body).to include(
          "errors" => [I18n.t("checklist.checkboxes_changed")],
          "updated_at" => post.reload.updated_at.iso8601(3),
          "retryable" => false,
        )
      end

      it "returns a 409 when the legacy checkbox count is stale" do
        legacy_toggle = toggle.merge(checkbox_source: nil, checkbox_count: 5)
        put "/checklist/toggle.json", params: params.merge(toggles: [legacy_toggle])

        expect(response.status).to eq(409)
        expect(response.parsed_body).to include(
          "errors" => [I18n.t("checklist.checkboxes_changed")],
          "updated_at" => post.reload.updated_at.iso8601(3),
          "retryable" => false,
        )
      end

      it "returns a 422 when the checkbox is permanent" do
        post.update_columns(raw: "[X] permanent\n[x] not permanent")

        legacy_toggle = toggle.merge(checkbox_source: nil, checkbox_count: 2)
        put "/checklist/toggle.json", params: params.merge(toggles: [legacy_toggle])

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to include(I18n.t("checklist.checkbox_locked"))
      end

      it "returns a 404 when the plugin is disabled" do
        SiteSetting.checklist_enabled = false

        put "/checklist/toggle.json", params: params

        expect(response.status).to eq(404)
      end

      it "returns a 422 with the error when the revision fails" do
        PostRevisor.any_instance.stubs(:revise!).returns(false)

        put "/checklist/toggle.json", params: params

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to include(I18n.t("checklist.revision_failed"))
      end
    end

    context "when logged in as a user who cannot edit the post" do
      fab!(:another_user, :user)

      before { sign_in(another_user) }

      it "returns a 403" do
        put "/checklist/toggle.json", params: params

        expect(response.status).to eq(403)
      end
    end
  end
end
