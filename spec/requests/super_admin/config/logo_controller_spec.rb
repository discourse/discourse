# frozen_string_literal: true

RSpec.describe SuperAdmin::Config::LogoController do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)
  fab!(:topic)

  describe "#og_image_preview" do
    before do
      TopicOgImageGenerator.any_instance.stubs(:generate_bytes).returns("\x89PNG\r\n\x1A\n".b)
    end

    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "returns a base64 data URI for the given topic" do
        get "/admin/config/logo/og-image-preview.json", params: { topic_id: topic.id }
        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["url"]).to start_with("data:image/png;base64,")
        expect(json["topic_id"]).to eq(topic.id)
        expect(json["topic_title"]).to eq(topic.title)
      end

      it "returns 400 when topic_id is missing" do
        get "/admin/config/logo/og-image-preview.json"
        expect(response.status).to eq(400)
      end

      it "returns 404 for a non-existent topic" do
        get "/admin/config/logo/og-image-preview.json", params: { topic_id: 0 }
        expect(response.status).to eq(404)
      end

      it "returns 422 when generation fails" do
        TopicOgImageGenerator.any_instance.stubs(:generate_bytes).returns(nil)
        get "/admin/config/logo/og-image-preview.json", params: { topic_id: topic.id }
        expect(response.status).to eq(422)
      end

      it "returns 422 when login_required is enabled" do
        SiteSetting.login_required = true
        TopicOgImageGenerator.any_instance.expects(:generate_bytes).never
        get "/admin/config/logo/og-image-preview.json", params: { topic_id: topic.id }
        expect(response.status).to eq(422)
      end

      it "returns 422 for personal messages without attempting to generate" do
        pm = Fabricate(:private_message_topic)
        TopicOgImageGenerator.any_instance.expects(:generate_bytes).never
        get "/admin/config/logo/og-image-preview.json", params: { topic_id: pm.id }
        expect(response.status).to eq(422)
      end

      it "returns 422 for topics in a read-restricted category" do
        private_category = Fabricate(:private_category, group: Fabricate(:group))
        topic.update!(category: private_category)
        TopicOgImageGenerator.any_instance.expects(:generate_bytes).never
        get "/admin/config/logo/og-image-preview.json", params: { topic_id: topic.id }
        expect(response.status).to eq(422)
      end

      it "does not persist an Upload" do
        expect {
          get "/admin/config/logo/og-image-preview.json", params: { topic_id: topic.id }
        }.not_to change { Upload.count }
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      it "denies access" do
        get "/admin/config/logo/og-image-preview.json", params: { topic_id: topic.id }
        expect(response.status).to eq(403)
      end
    end

    context "when logged in as a regular user" do
      before { sign_in(user) }

      it "denies access" do
        get "/admin/config/logo/og-image-preview.json", params: { topic_id: topic.id }
        expect(response.status).to eq(404)
      end
    end

    context "when not logged in" do
      it "denies access" do
        get "/admin/config/logo/og-image-preview.json", params: { topic_id: topic.id }
        expect(response.status).to eq(404)
      end
    end
  end
end
