# frozen_string_literal: true

RSpec.describe Checklist::CheckboxesController do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic:, user:, raw: "[ ] task") }

  before { SiteSetting.checklist_enabled = true }

  describe "#toggle" do
    it "requires authentication" do
      put "/checklist/toggle.json", params: { post_id: post.id, checkbox_offset: 0 }
      expect(response.status).to eq(403)
    end

    context "when logged in" do
      before { sign_in(user) }

      it "returns 204 on success" do
        put "/checklist/toggle.json", params: { post_id: post.id, checkbox_offset: 0 }
        expect(response.status).to eq(204)
      end

      it "returns 403 when user cannot edit" do
        other_user = Fabricate(:user)
        sign_in(other_user)

        put "/checklist/toggle.json", params: { post_id: post.id, checkbox_offset: 0 }
        expect(response.status).to eq(403)
      end

      it "returns 404 when post not found" do
        put "/checklist/toggle.json", params: { post_id: -1, checkbox_offset: 0 }
        expect(response.status).to eq(404)
      end

      it "returns 422 when offset is invalid" do
        put "/checklist/toggle.json", params: { post_id: post.id, checkbox_offset: 99 }
        expect(response.status).to eq(422)
      end
    end

    context "when plugin is disabled" do
      before do
        SiteSetting.checklist_enabled = false
        sign_in(user)
      end

      it "returns 404" do
        put "/checklist/toggle.json", params: { post_id: post.id, checkbox_offset: 0 }
        expect(response.status).to eq(404)
      end
    end
  end
end
