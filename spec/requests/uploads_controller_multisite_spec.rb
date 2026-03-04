# frozen_string_literal: true

RSpec.describe UploadsController, type: %i[multisite request] do
  let!(:user) { Fabricate(:user) }

  before { freeze_time }

  describe "show_short" do
    before { sign_in(user) }

    context "when s3 uploads is enabled" do
      before { setup_s3 }

      fab!(:upload, :upload_s3)

      context "when secure uploads is enabled and the upload is secure" do
        before do
          SiteSetting.secure_uploads = true
          upload.update(secure: true)
        end

        it "redirects to the signed_url_for_path with the multisite DB name in the url" do
          get(upload.short_path)

          expect(response).to redirect_to(/#{RailsMultisite::ConnectionManagement.current_db}/)
        end
      end
    end
  end

  describe "show" do
    let!(:user) { Fabricate(:user) }
    let(:upload) do
      UploadCreator.new(file_from_fixtures("logo.jpg"), "logo.jpg").create_for(user.id)
    end

    context "when user is signed in" do
      before { sign_in(user) }

      it "returns a 200" do
        get(
          "/uploads/#{RailsMultisite::ConnectionManagement.current_db}/#{upload.sha1}.#{upload.extension}",
        )
        expect(response).to have_http_status(:ok)
      end
    end

    context "when user is not signed in" do
      context "when prevent_anons_from_downloading_files is enabled" do
        before { SiteSetting.prevent_anons_from_downloading_files = true }

        it "returns a 404" do
          get(
            "/uploads/#{RailsMultisite::ConnectionManagement.current_db}/#{upload.sha1}.#{upload.extension}",
          )
          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context "when requesting an upload from a different site (logged in on request site, anon on target site)" do
      before do
        sign_in(user)
        RailsMultisite::ConnectionManagement.with_connection("second") do
          second_user =
            Fabricate(
              :user,
              username: "s2_#{SecureRandom.hex(3)}",
              email: "s2_#{SecureRandom.hex(4)}@example.com",
            )
          upload =
            UploadCreator.new(file_from_fixtures("logo.jpg"), "logo.jpg").create_for(second_user.id)
          @upload_on_second_sha1 = upload.sha1
          @upload_on_second_extension = upload.extension
        end
        RailsMultisite::ConnectionManagement.establish_connection(db: "default")
      end

      it "returns 200 when prevent_anons_from_downloading_files is false" do
        get("/uploads/second/#{@upload_on_second_sha1}.#{@upload_on_second_extension}")
        expect(response).to have_http_status(:ok)
      end

      context "when prevent_anons_from_downloading_files is enabled" do
        before { SiteSetting.prevent_anons_from_downloading_files = true }

        it "returns 404 because current_user is evaluated for target site (anon on target)" do
          get("/uploads/second/#{@upload_on_second_sha1}.#{@upload_on_second_extension}")
          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context "when requesting an upload from a different site as anonymous (anon on target site)" do
      before do
        RailsMultisite::ConnectionManagement.with_connection("second") do
          second_user =
            Fabricate(
              :user,
              username: "s2a_#{SecureRandom.hex(3)}",
              email: "s2a_#{SecureRandom.hex(4)}@example.com",
            )
          upload =
            UploadCreator.new(file_from_fixtures("logo.jpg"), "logo.jpg").create_for(second_user.id)
          @upload_on_second_sha1 = upload.sha1
          @upload_on_second_extension = upload.extension
        end
        RailsMultisite::ConnectionManagement.establish_connection(db: "default")
      end

      context "when prevent_anons_from_downloading_files is enabled" do
        before { SiteSetting.prevent_anons_from_downloading_files = true }

        it "returns 404 because current_user is nil on target site" do
          get("/uploads/second/#{@upload_on_second_sha1}.#{@upload_on_second_extension}")
          expect(response).to have_http_status(:not_found)
        end
      end
    end
  end
end
