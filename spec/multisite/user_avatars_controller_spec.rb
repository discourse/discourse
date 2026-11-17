# frozen_string_literal: true

RSpec.describe UserAvatarsController, type: :multisite do
  include RSpec::Rails::RequestExampleGroup
  include IntegrationHelpers

  describe "#show" do
    shared_examples "tenant-isolated retained avatars" do |source|
      it "restricts retained #{source} avatars to the originating tenant" do
        viewer = Fabricate(:user)
        admin = Fabricate(:admin)

        test_multisite_connection("second") do
          user = Fabricate(:user, id: viewer.id)
          upload =
            File.open(file_from_fixtures("cropped.png")) do |file|
              UploadCreator.new(file, "retained-avatar.png", type: "avatar").create_for(user.id)
            end
          if source == :associated_account
            Fabricate(:user_associated_account, user: user, avatar_upload_id: upload.id)
          else
            user.user_avatar.update!("#{source}_upload_id" => upload.id)
          end
          path = UserAvatar.local_avatar_url("test2.localhost", user.username_lower, upload.id, 50)
          image = File.binread(Discourse.store.path_for(upload.get_optimized_image(50, 50)))

          host! "test2.localhost"
          sign_in(user)
          get path
          expect(response).to be_successful
          expect(response.body).to eq(image)
          expect(response.headers["Cache-Control"]).to eq("private, no-store")
          sign_out

          test_multisite_connection("default") do
            host! "test.localhost"
            [viewer, admin].each do |principal|
              sign_in(principal)
              get path
              expect(response).to be_forbidden
              expect(response.headers["Cache-Control"]).to eq("private, no-store")
              sign_out
            end
          end

          user.update!(uploaded_avatar: upload)
          test_multisite_connection("default") do
            get path
            expect(response).to be_successful
            expect(response.body).to eq(image)
            expect(response.headers["Cache-Control"]).to include("public", "immutable")
          end
        end
      end
    end

    include_examples "tenant-isolated retained avatars", :custom
    include_examples "tenant-isolated retained avatars", :gravatar
    include_examples "tenant-isolated retained avatars", :associated_account
  end
end
