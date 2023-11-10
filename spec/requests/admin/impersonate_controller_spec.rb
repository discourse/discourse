# frozen_string_literal: true

RSpec.describe Admin::ImpersonateController do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)
  fab!(:another_admin) { Fabricate(:admin) }

  describe "#index" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "returns success" do
        get "/admin/impersonate.json"

        expect(response.status).to eq(200)
      end
    end

    shared_examples "impersonation inaccessible" do
      it "denies access with a 404 response" do
        get "/admin/impersonate.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "impersonation inaccessible"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "impersonation inaccessible"
    end
  end

  describe "#create" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "requires a username_or_email parameter" do
        post "/admin/impersonate.json"
        expect(response.status).to eq(400)
        expect(session[:current_user_id]).to eq(admin.id)
      end

      it "returns 404 when that user does not exist" do
        post "/admin/impersonate.json", params: { username_or_email: "hedonismbot" }
        expect(response.status).to eq(404)
        expect(session[:current_user_id]).to eq(admin.id)
      end

      it "raises an invalid access error if the user can't be impersonated" do
        post "/admin/impersonate.json", params: { username_or_email: another_admin.email }
        expect(response.status).to eq(403)
        expect(session[:current_user_id]).to eq(admin.id)
      end

      context "with success" do
        it "succeeds and logs the impersonation" do
          expect do
            post "/admin/impersonate.json", params: { username_or_email: user.username }
          end.to change { UserHistory.where(action: UserHistory.actions[:impersonate]).count }.by(1)

          expect(response.status).to eq(200)
          expect(session[:current_user_id]).to eq(user.id)
        end

        it "also works with an email address" do
          post "/admin/impersonate.json", params: { username_or_email: user.email }
          expect(response.status).to eq(200)
          expect(session[:current_user_id]).to eq(user.id)
        end
      end
    end

    shared_examples "impersonation not allowed" do
      it "prevents impersonation with a with 404 response" do
        expect do
          post "/admin/impersonate.json", params: { username_or_email: user.username }
        end.not_to change { UserHistory.where(action: UserHistory.actions[:impersonate]).count }

        expect(response.status).to eq(404)
        expect(session[:current_user_id]).to eq(current_user.id)
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "impersonation not allowed" do
        let(:current_user) { moderator }
      end
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "impersonation not allowed" do
        let(:current_user) { user }
      end
    end
  end
end
