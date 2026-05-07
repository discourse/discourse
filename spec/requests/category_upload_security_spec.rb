# frozen_string_literal: true

RSpec.describe "Category upload security" do
  fab!(:admin)
  fab!(:moderator)
  fab!(:other_user) { Fabricate(:user, username: "other-user", email: "other@example.com") }
  fab!(:category) { Fabricate(:category, user: admin, name: "Artwork Security") }
  fab!(:secure_upload) { Fabricate(:secure_upload, user: other_user) }

  describe "PUT /categories/:id.json" do
    before do
      setup_s3
      SiteSetting.moderators_manage_categories = true
      SiteSetting.secure_uploads = true
      sign_in(moderator)
    end

    it "rejects secure uploads the editor cannot reuse" do
      put "/categories/#{category.id}.json", params: { uploaded_logo_id: secure_upload.id }

      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to include(I18n.t("upload.unauthorized"))
      expect(category.reload.uploaded_logo_id).to be_nil
    end
  end

  describe "GET /c/:slug/find_by_slug.json" do
    it "serializes category artwork through the secure upload helper" do
      setup_s3
      SiteSetting.secure_uploads = true
      secure_upload = Fabricate(:secure_upload_s3, user: other_user)
      category.update_columns(uploaded_logo_id: secure_upload.id)

      get "/c/#{category.slug}/find_by_slug.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body.dig("category", "uploaded_logo", "url")).to eq(
        UrlHelper.cook_url(secure_upload.url, secure: true),
      )
    end
  end
end
