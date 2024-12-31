# frozen_string_literal: true

RSpec.describe Admin::EmojiController do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)
  fab!(:upload)

  describe "#index" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "returns a list of custom emoji" do
        CustomEmoji.create!(name: "osama-test-emoji", upload: upload, user: admin)
        Emoji.clear_cache

        get "/admin/config/emoji.json"
        expect(response.status).to eq(200)

        json = response.parsed_body
        expect(json[0]["name"]).to eq("osama-test-emoji")
        expect(json[0]["url"]).to eq(upload.url)
        expect(json[0]["created_by"]).to eq(admin.username)
      end
    end

    shared_examples "custom emoji inaccessible" do
      it "denies access with a 404 response" do
        get "/admin/config/emoji.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "custom emoji inaccessible"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "custom emoji inaccessible"
    end
  end

  describe "#create" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      context "when upload is invalid" do
        it "should publish the right error" do
          post "/admin/config/emoji.json",
               params: {
                 name: "test",
                 file: fixture_file_upload("#{Rails.root}/spec/fixtures/images/fake.jpg"),
               }

          expect(response.status).to eq(422)
          parsed = response.parsed_body
          expect(parsed["errors"]).to eq([I18n.t("upload.images.size_not_found")])
        end
      end

      context "when emoji name already exists" do
        it "should publish the right error" do
          CustomEmoji.create!(name: "test", upload: upload)

          post "/admin/config/emoji.json",
               params: {
                 name: "test",
                 file: fixture_file_upload("#{Rails.root}/spec/fixtures/images/logo.png"),
               }

          expect(response.status).to eq(422)
          parsed = response.parsed_body
          expect(parsed["errors"]).to eq(
            ["Name #{I18n.t("activerecord.errors.models.custom_emoji.attributes.name.taken")}"],
          )
        end
      end

      it "should allow an admin to add a custom emoji" do
        Emoji.expects(:clear_cache)

        post "/admin/config/emoji.json",
             params: {
               name: "test",
               file: fixture_file_upload("#{Rails.root}/spec/fixtures/images/logo.png"),
             }

        custom_emoji = CustomEmoji.last
        upload = custom_emoji.upload

        expect(upload.original_filename).to eq("logo.png")

        data = response.parsed_body
        expect(response.status).to eq(200)
        expect(data["errors"]).to eq(nil)
        expect(data["name"]).to eq(custom_emoji.name)
        expect(data["url"]).to eq(upload.url)
        expect(custom_emoji.group).to eq(nil)
        expect(custom_emoji.user_id).to eq(admin.id)
      end

      it "should log the action" do
        Emoji.expects(:clear_cache)

        post "/admin/config/emoji.json",
             params: {
               name: "test",
               file: fixture_file_upload("#{Rails.root}/spec/fixtures/images/logo.png"),
             }

        last_log = UserHistory.last

        expect(last_log.action).to eq(UserHistory.actions[:custom_emoji_create])
        expect(last_log.acting_user_id).to eq(admin.id)
        expect(last_log.new_value).to eq("test")
      end

      it "should allow an admin to add a custom emoji with a custom group" do
        Emoji.expects(:clear_cache)

        post "/admin/config/emoji.json",
             params: {
               name: "test",
               group: "Foo",
               file: fixture_file_upload("#{Rails.root}/spec/fixtures/images/logo.png"),
             }

        custom_emoji = CustomEmoji.last

        data = response.parsed_body
        expect(response.status).to eq(200)
        expect(custom_emoji.group).to eq("foo")
      end

      it "should fix up the emoji name" do
        Emoji.expects(:clear_cache).times(3)

        post "/admin/config/emoji.json",
             params: {
               name: "test.png",
               file: fixture_file_upload("#{Rails.root}/spec/fixtures/images/logo.png"),
             }

        custom_emoji = CustomEmoji.last
        upload = custom_emoji.upload

        expect(upload.original_filename).to eq("logo.png")
        expect(custom_emoji.name).to eq("test")
        expect(response.status).to eq(200)

        post "/admin/config/emoji.json",
             params: {
               name: "st&#* onk$",
               file: fixture_file_upload("#{Rails.root}/spec/fixtures/images/logo.png"),
             }

        custom_emoji = CustomEmoji.last
        expect(custom_emoji.name).to eq("st_onk_")
        expect(response.status).to eq(200)

        post "/admin/config/emoji.json",
             params: {
               name: "PaRTYpaRrot",
               file: fixture_file_upload("#{Rails.root}/spec/fixtures/images/logo.png"),
             }

        custom_emoji = CustomEmoji.last
        expect(custom_emoji.name).to eq("partyparrot")
        expect(response.status).to eq(200)
      end
    end

    shared_examples "custom emoji creation not allowed" do
      it "prevents creation with a 404 response" do
        post "/admin/config/emoji.json",
             params: {
               name: "test",
               file: fixture_file_upload("#{Rails.root}/spec/fixtures/images/logo.png"),
             }

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "custom emoji creation not allowed"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "custom emoji creation not allowed"
    end
  end

  describe "#destroy" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "should allow an admin to delete a custom emoji" do
        custom_emoji = CustomEmoji.create!(name: "test", upload: upload)
        Emoji.clear_cache

        expect do
          delete "/admin/config/emoji/#{custom_emoji.name}.json", params: { name: "test" }
        end.to change { CustomEmoji.count }.by(-1)
      end

      it "should log the action" do
        custom_emoji = CustomEmoji.create!(name: "test", upload: upload)
        Emoji.clear_cache

        delete "/admin/config/emoji/#{custom_emoji.name}.json", params: { name: "test" }

        last_log = UserHistory.last

        expect(last_log.action).to eq(UserHistory.actions[:custom_emoji_destroy])
        expect(last_log.acting_user_id).to eq(admin.id)
        expect(last_log.previous_value).to eq("test")
      end
    end

    shared_examples "custom emoji deletion not allowed" do
      it "prevents deletion with a 404 response" do
        custom_emoji = CustomEmoji.create!(name: "test", upload: upload)
        Emoji.clear_cache

        delete "/admin/config/emoji/#{custom_emoji.name}.json", params: { name: "test" }

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "custom emoji deletion not allowed"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "custom emoji deletion not allowed"
    end
  end
end
