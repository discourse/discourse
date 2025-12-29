# frozen_string_literal: true

RSpec.describe Checklist::CheckboxesController do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:other_user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic:, user:, raw: "- [ ] first\n- [x] second\n- [ ] third") }

  before { SiteSetting.checklist_enabled = true }

  describe "#toggle" do
    context "when not logged in" do
      it "returns 403" do
        put "/checklist/toggle.json", params: { post_id: post.id, checkbox_offset: 2 }

        expect(response.status).to eq(403)
      end
    end

    context "when logged in" do
      before { sign_in(user) }

      it "toggles an unchecked checkbox" do
        put "/checklist/toggle.json", params: { post_id: post.id, checkbox_offset: 2 }

        expect(response.status).to eq(200)

        json = response.parsed_body
        expect(json["checked"]).to eq(true)
        expect(json["post_id"]).to eq(post.id)

        post.reload
        expect(post.raw).to eq("- [x] first\n- [x] second\n- [ ] third")
      end

      it "toggles a checked checkbox" do
        put "/checklist/toggle.json", params: { post_id: post.id, checkbox_offset: 14 }

        expect(response.status).to eq(200)

        json = response.parsed_body
        expect(json["checked"]).to eq(false)

        post.reload
        expect(post.raw).to eq("- [ ] first\n- [ ] second\n- [ ] third")
      end

      it "creates a revision" do
        expect {
          put "/checklist/toggle.json", params: { post_id: post.id, checkbox_offset: 2 }
        }.to change { PostRevision.count }.by(1)
      end

      it "publishes to MessageBus" do
        messages =
          MessageBus.track_publish("/checklist/#{topic.id}") do
            put "/checklist/toggle.json", params: { post_id: post.id, checkbox_offset: 2 }
          end

        expect(messages.length).to eq(1)
        expect(messages.first.data).to include(post_id: post.id, checkbox_offset: 2, checked: true)
      end
    end

    context "when user cannot edit the post" do
      before { sign_in(other_user) }

      it "returns 403" do
        put "/checklist/toggle.json", params: { post_id: post.id, checkbox_offset: 2 }

        expect(response.status).to eq(403)
      end
    end

    context "when checklist plugin is disabled" do
      before do
        SiteSetting.checklist_enabled = false
        sign_in(user)
      end

      it "returns 404" do
        put "/checklist/toggle.json", params: { post_id: post.id, checkbox_offset: 2 }

        expect(response.status).to eq(404)
      end
    end

    context "when post is not found" do
      before { sign_in(user) }

      it "returns 404" do
        put "/checklist/toggle.json", params: { post_id: -1, checkbox_offset: 2 }

        expect(response.status).to eq(404)
      end
    end

    context "when offset is invalid" do
      before { sign_in(user) }

      it "returns 422 for out of bounds offset" do
        put "/checklist/toggle.json", params: { post_id: post.id, checkbox_offset: 9999 }

        expect(response.status).to eq(422)
      end

      it "returns 422 for offset not pointing to a checkbox" do
        put "/checklist/toggle.json", params: { post_id: post.id, checkbox_offset: 0 }

        expect(response.status).to eq(422)
      end
    end

    context "with permanent checkbox [X]" do
      fab!(:post_with_permanent) { Fabricate(:post, topic:, user:, raw: "[X] permanent checkbox") }

      before { sign_in(user) }

      it "returns 422" do
        put "/checklist/toggle.json",
            params: {
              post_id: post_with_permanent.id,
              checkbox_offset: 0,
            }

        expect(response.status).to eq(422)
      end

      it "does not modify the post" do
        put "/checklist/toggle.json",
            params: {
              post_id: post_with_permanent.id,
              checkbox_offset: 0,
            }

        post_with_permanent.reload
        expect(post_with_permanent.raw).to eq("[X] permanent checkbox")
      end
    end

    context "with image alt text" do
      fab!(:post_with_image) { Fabricate(:post, topic:, user:, raw: "![](image.png) text") }

      before { sign_in(user) }

      it "returns 422 for offset pointing to image alt brackets" do
        put "/checklist/toggle.json", params: { post_id: post_with_image.id, checkbox_offset: 1 }

        expect(response.status).to eq(422)
      end
    end

    context "with escaped checkbox" do
      fab!(:post_with_escaped) { Fabricate(:post, topic:, user:, raw: "\\[ ] escaped checkbox") }

      before { sign_in(user) }

      it "returns 422 for offset pointing to escaped bracket" do
        put "/checklist/toggle.json", params: { post_id: post_with_escaped.id, checkbox_offset: 1 }

        expect(response.status).to eq(422)
      end
    end
  end
end
