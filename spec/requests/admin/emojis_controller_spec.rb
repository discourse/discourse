# frozen_string_literal: true

require "zip"
require "csv"

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
                 file: fixture_file_upload("#{Rails.root.join("spec/fixtures/images/fake.jpg")}"),
               }

          expect(response.status).to eq(422)
          parsed = response.parsed_body
          expect(parsed["errors"]).to eq([I18n.t("upload.images.size_not_found")])
        end
      end

      it "returns a controlled validation error without an upload" do
        post "/admin/config/emoji.json", params: { name: "test" }

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to eq(["File can't be blank"])
      end

      context "when emoji name already exists" do
        it "should publish the right error" do
          CustomEmoji.create!(name: "test", upload: upload)

          post "/admin/config/emoji.json",
               params: {
                 name: "test",
                 file: fixture_file_upload("#{Rails.root.join("spec/fixtures/images/logo.png")}"),
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
               file: fixture_file_upload("#{Rails.root.join("spec/fixtures/images/logo.png")}"),
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
               file: fixture_file_upload("#{Rails.root.join("spec/fixtures/images/logo.png")}"),
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
               file: fixture_file_upload("#{Rails.root.join("spec/fixtures/images/logo.png")}"),
             }

        custom_emoji = CustomEmoji.last

        expect(response.status).to eq(200)
        expect(custom_emoji.group).to eq("foo")
      end

      it "should allow an admin to add a custom SVG emoji" do
        Emoji.expects(:clear_cache)

        post "/admin/config/emoji.json",
             params: {
               name: "test_svg",
               file: fixture_file_upload("#{Rails.root.join("spec/fixtures/images/image.svg")}"),
             }

        expect(response.status).to eq(200)

        custom_emoji = CustomEmoji.last
        upload = custom_emoji.upload

        expect(upload.original_filename).to eq("image.svg")
        expect(upload.extension).to eq("svg")
      end

      it "should allow an admin to add a custom animated GIF emoji" do
        Emoji.expects(:clear_cache)

        post "/admin/config/emoji.json",
             params: {
               name: "test_gif",
               file: fixture_file_upload("#{Rails.root.join("spec/fixtures/images/animated.gif")}"),
             }

        expect(response.status).to eq(200)

        custom_emoji = CustomEmoji.last
        upload = custom_emoji.upload

        expect(upload.original_filename).to eq("animated.gif")
        expect(upload.extension).to eq("gif")
      end

      it "should fix up the emoji name" do
        Emoji.expects(:clear_cache).times(3)

        post "/admin/config/emoji.json",
             params: {
               name: "test.png",
               file: fixture_file_upload("#{Rails.root.join("spec/fixtures/images/logo.png")}"),
             }

        custom_emoji = CustomEmoji.last
        upload = custom_emoji.upload

        expect(upload.original_filename).to eq("logo.png")
        expect(custom_emoji.name).to eq("test")
        expect(response.status).to eq(200)

        post "/admin/config/emoji.json",
             params: {
               name: "st&#* onk$",
               file: fixture_file_upload("#{Rails.root.join("spec/fixtures/images/logo.png")}"),
             }

        custom_emoji = CustomEmoji.last
        expect(custom_emoji.name).to eq("st_onk_")
        expect(response.status).to eq(200)

        post "/admin/config/emoji.json",
             params: {
               name: "PaRTYpaRrot",
               file: fixture_file_upload("#{Rails.root.join("spec/fixtures/images/logo.png")}"),
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
               file: fixture_file_upload("#{Rails.root.join("spec/fixtures/images/logo.png")}"),
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

  describe "#export" do
    fab!(:png_upload) do
      UploadCreator.new(
        file_from_fixtures("logo.png"),
        "logo.png",
        type: "custom_emoji",
      ).create_for(Discourse.system_user.id)
    end

    fab!(:emoji_a) { CustomEmoji.create!(name: "emoji-a", upload: png_upload, user: admin) }
    fab!(:emoji_b) do
      CustomEmoji.create!(name: "emoji-b", upload: png_upload, group: "fun", user: admin)
    end

    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "streams a ZIP containing emojis.csv and image files" do
        post "/admin/config/emoji/export", params: { names: %w[emoji-a emoji-b] }, as: :json

        expect(response.status).to eq(200)
        expect(response.headers["Content-Type"]).to include("application/zip")

        Tempfile.create(%w[export_test_ .zip]) do |f|
          f.binmode
          f.write(response.body)
          f.rewind

          Zip::File.open(f.path) do |zip|
            entries = zip.entries.map(&:name)
            expect(entries).to include("emojis.csv")
            expect(entries).to include("emoji-a.png")
            expect(entries).to include("emoji-b.png")

            csv = zip.read("emojis.csv")
            rows = CSV.parse(csv, headers: true)
            expect(rows.map { |r| r["name"] }).to contain_exactly("emoji-a", "emoji-b")
            emoji_b_row = rows.find { |r| r["name"] == "emoji-b" }
            expect(emoji_b_row["group"]).to eq("fun")
          end
        end
      end

      it "returns 422 when no names are provided" do
        post "/admin/config/emoji/export", as: :json
        expect(response.status).to eq(422)
      end
    end

    shared_examples "export not allowed" do
      it "denies access with a 404 response" do
        post "/admin/config/emoji/export", params: { names: ["emoji-a"] }, as: :json
        expect(response.status).to eq(404)
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }
      include_examples "export not allowed"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }
      include_examples "export not allowed"
    end
  end

  describe "#import_preview" do
    let(:image_path) { Rails.root.join("spec/fixtures/images/logo.png") }

    def build_emoji_zip(csv_content, images = {})
      tmp = Tempfile.new(%w[emoji_import_ .zip])
      tmp.close

      Zip::File.open(tmp.path, create: true) do |zip|
        zip.get_output_stream("emojis.csv") { |f| f.write(csv_content) }
        images.each { |filename, path| zip.add(filename, path) }
      end

      Rack::Test::UploadedFile.new(tmp.path, "application/zip")
    end

    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "returns a preview with new emojis correctly categorised" do
        zip =
          build_emoji_zip(
            "name,group,filename\npreview-emoji,,preview-emoji.png\n",
            { "preview-emoji.png" => image_path },
          )

        post "/admin/config/emoji/import_preview.json", params: { file: zip }

        expect(response.status).to eq(200)
        body = response.parsed_body
        expect(body["token"]).to be_present
        expect(body["rows"].length).to eq(1)
        expect(body["rows"][0]["category"]).to eq("new")
        expect(body["rows"][0]["name"]).to eq("preview-emoji")
      end

      it "categorises existing emoji with a group change as conflict_group" do
        existing_upload =
          UploadCreator.new(
            file_from_fixtures("logo.png"),
            "logo.png",
            type: "custom_emoji",
          ).create_for(admin.id)
        CustomEmoji.create!(
          name: "existing-emoji",
          upload: existing_upload,
          group: "old-group",
          user: admin,
        )

        zip =
          build_emoji_zip(
            "name,group,filename\nexisting-emoji,new-group,existing-emoji.png\n",
            { "existing-emoji.png" => image_path },
          )

        post "/admin/config/emoji/import_preview.json", params: { file: zip }

        expect(response.status).to eq(200)
        row = response.parsed_body["rows"][0]
        expect(row["category"]).to eq("conflict_group")
      end

      it "flags missing image file in ZIP as invalid" do
        zip = build_emoji_zip("name,group,filename\nmissing-img,,missing-img.png\n")

        post "/admin/config/emoji/import_preview.json", params: { file: zip }

        expect(response.status).to eq(200)
        row = response.parsed_body["rows"][0]
        expect(row["category"]).to eq("invalid")
      end

      it "flags unsupported extension as invalid" do
        zip = build_emoji_zip("name,group,filename\nbad-ext,,bad-ext.bmp\n")

        post "/admin/config/emoji/import_preview.json", params: { file: zip }

        row = response.parsed_body["rows"][0]
        expect(row["category"]).to eq("invalid")
        expect(row["errors"].join).to include("bmp")
      end

      it "returns 422 when no file is provided" do
        post "/admin/config/emoji/import_preview.json"
        expect(response.status).to eq(422)
      end

      it "returns 422 when ZIP has no emojis.csv" do
        tmp = Tempfile.new(%w[no_csv_ .zip])
        tmp.close
        Zip::File.open(tmp.path, create: true) do |z|
          z.get_output_stream("readme.txt") { |f| f.write("hi") }
        end
        zip = Rack::Test::UploadedFile.new(tmp.path, "application/zip")

        post "/admin/config/emoji/import_preview.json", params: { file: zip }
        expect(response.status).to eq(422)
      end

      it "returns 422 when the manifest only contains headers" do
        zip = build_emoji_zip("name,group,filename\n")

        post "/admin/config/emoji/import_preview.json", params: { file: zip }

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to eq([I18n.t("emoji.import.empty_manifest")])
      end

      it "stores a manifest in Redis" do
        zip =
          build_emoji_zip(
            "name,group,filename\nredis-test,,redis-test.png\n",
            { "redis-test.png" => image_path },
          )

        post "/admin/config/emoji/import_preview.json", params: { file: zip }

        token = response.parsed_body["token"]
        redis_key = "emoji_import_preview:#{admin.id}:#{token}"
        expect(Discourse.redis.exists?(redis_key)).to eq(true)
      end
    end

    shared_examples "import preview not allowed" do
      it "denies access with a 404 response" do
        post "/admin/config/emoji/import_preview.json"
        expect(response.status).to eq(404)
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }
      include_examples "import preview not allowed"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }
      include_examples "import preview not allowed"
    end
  end

  describe "#import_confirm" do
    let(:image_path) { Rails.root.join("spec/fixtures/images/logo.png") }

    def store_manifest(user, token, rows)
      key = "emoji_import_preview:#{user.id}:#{token}"
      Discourse.redis.setex(key, 2.hours.to_i, rows.to_json)
    end

    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "creates new emojis and clears the Redis manifest" do
        staged_upload =
          UploadCreator.new(
            file_from_fixtures("logo.png"),
            "logo.png",
            type: "custom_emoji",
          ).create_for(admin.id)
        token = SecureRandom.hex
        store_manifest(
          admin,
          token,
          [
            {
              name: "confirm-new",
              group: "default",
              filename: "confirm-new.png",
              category: "new",
              upload_id: staged_upload.id,
            },
          ],
        )

        expect do
          post "/admin/config/emoji/import_confirm.json", params: { token: token }
        end.to change { CustomEmoji.exists?(name: "confirm-new") }.from(false).to(true)

        expect(response.status).to eq(200)
        expect(response.parsed_body["created"]).to eq(1)
        expect(Discourse.redis.exists?("emoji_import_preview:#{admin.id}:#{token}")).to eq(false)
      end

      it "rolls back all changes on failure" do
        staged_upload =
          UploadCreator.new(
            file_from_fixtures("logo.png"),
            "logo.png",
            type: "custom_emoji",
          ).create_for(admin.id)
        token = SecureRandom.hex
        store_manifest(
          admin,
          token,
          [
            {
              name: "rollback-ok",
              group: "default",
              filename: "rollback-ok.png",
              category: "new",
              upload_id: staged_upload.id,
            },
            {
              name: "",
              group: "default",
              filename: "bad.png",
              category: "new",
              upload_id: staged_upload.id,
            },
          ],
        )

        post "/admin/config/emoji/import_confirm.json", params: { token: token }

        expect(CustomEmoji.exists?(name: "rollback-ok")).to eq(false)
      end

      it "skips identical rows without creating records" do
        existing = CustomEmoji.create!(name: "same-emoji", upload: upload, user: admin)
        token = SecureRandom.hex
        store_manifest(
          admin,
          token,
          [
            {
              name: "same-emoji",
              group: "default",
              filename: "same-emoji.png",
              category: "identical",
            },
          ],
        )

        post "/admin/config/emoji/import_confirm.json", params: { token: token }

        expect(response.parsed_body["skipped"]).to eq(1)
        expect(existing.reload.upload_id).to eq(existing.upload_id)
      end

      it "respects keep resolution for conflict rows" do
        staged_upload =
          UploadCreator.new(
            file_from_fixtures("logo.png"),
            "logo.png",
            type: "custom_emoji",
          ).create_for(admin.id)
        existing = CustomEmoji.create!(name: "keep-me", upload: upload, group: "old", user: admin)
        token = SecureRandom.hex
        store_manifest(
          admin,
          token,
          [
            {
              name: "keep-me",
              group: "new-group",
              filename: "keep-me.png",
              category: "conflict_group",
              upload_id: staged_upload.id,
            },
          ],
        )

        post "/admin/config/emoji/import_confirm.json",
             params: {
               token: token,
               resolutions: {
                 "keep-me" => "keep",
               },
             }

        expect(existing.reload.group).to eq("old")
      end

      it "returns 422 when the session token is missing or expired" do
        post "/admin/config/emoji/import_confirm.json", params: { token: "nonexistent-token" }
        expect(response.status).to eq(422)
      end
    end

    shared_examples "import confirm not allowed" do
      it "denies access with a 404 response" do
        post "/admin/config/emoji/import_confirm.json", params: { token: "x" }
        expect(response.status).to eq(404)
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }
      include_examples "import confirm not allowed"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }
      include_examples "import confirm not allowed"
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

        expect(response.status).to eq(200)
        expect(response.parsed_body["success"]).to eq("OK")
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
