# frozen_string_literal: true

RSpec.describe Checklist::CheckboxesController do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:topic) { Fabricate(:topic, user: user) }

  fab!(:post) { Fabricate(:post, topic: topic, user: user, raw: "- [ ] first\n- [x] second") }

  before { SiteSetting.checklist_enabled = true }

  describe "#toggle" do
    let(:params) { { post_id: post.id, checkbox_index: 0, checkbox_count: 2, checked: true } }

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

        expect(response.status).to eq(204)
        expect(post.reload.raw).to eq("- [x] first\n- [x] second")
      end

      it "succeeds without changes when the state already matches" do
        expect {
          put "/checklist/toggle.json", params: params.merge(checked: false)
        }.not_to change { post.reload.raw }

        expect(response.status).to eq(204)
      end

      it "returns a 400 when params are missing" do
        put "/checklist/toggle.json", params: { post_id: post.id }

        expect(response.status).to eq(400)
        expect(response.parsed_body["errors"]).to be_present
      end

      it "returns a 400 when params are invalid" do
        put "/checklist/toggle.json", params: params.merge(checkbox_index: -1)

        expect(response.status).to eq(400)
        expect(response.parsed_body["errors"]).to be_present
      end

      it "returns a 404 when the post does not exist" do
        put "/checklist/toggle.json", params: params.merge(post_id: -1)

        expect(response.status).to eq(404)
      end

      it "returns a 409 when the client checkbox count is stale" do
        put "/checklist/toggle.json", params: params.merge(checkbox_count: 5)

        expect(response.status).to eq(409)
        expect(response.parsed_body["errors"]).to include(I18n.t("checklist.checkboxes_changed"))
      end

      it "returns a 422 when the checkbox is permanent" do
        post.update_columns(raw: "[X] permanent\n[x] not permanent")

        put "/checklist/toggle.json", params: params

        expect(response.status).to eq(422)
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
