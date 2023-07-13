# frozen_string_literal: true

RSpec.describe Admin::EmbeddableHostsController do
  fab!(:admin) { Fabricate(:admin) }
  fab!(:moderator) { Fabricate(:moderator) }
  fab!(:user) { Fabricate(:user) }
  fab!(:embeddable_host) { Fabricate(:embeddable_host) }

  describe "#create" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "logs embeddable host create" do
        post "/admin/embeddable_hosts.json", params: { embeddable_host: { host: "test.com" } }

        expect(response.status).to eq(200)
        expect(
          UserHistory.where(
            acting_user_id: admin.id,
            action: UserHistory.actions[:embeddable_host_create],
          ).exists?,
        ).to eq(true)
      end
    end

    shared_examples "embeddable host creation not allowed" do
      it "prevents embeddable host creation with a 404 response" do
        post "/admin/embeddable_hosts.json", params: { embeddable_host: { host: "test.com" } }

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "embeddable host creation not allowed"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "embeddable host creation not allowed"
    end
  end

  describe "#update" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "logs embeddable host update" do
        category = Fabricate(:category)

        put "/admin/embeddable_hosts/#{embeddable_host.id}.json",
            params: {
              embeddable_host: {
                host: "test.com",
                category_id: category.id,
              },
            }

        expect(response.status).to eq(200)

        history_exists =
          UserHistory.where(
            acting_user_id: admin.id,
            action: UserHistory.actions[:embeddable_host_update],
            new_value: "category_id: #{category.id}, host: test.com",
          ).exists?

        expect(history_exists).to eq(true)
      end
    end

    shared_examples "embeddable host update not allowed" do
      it "prevents updates with a 404 response" do
        category = Fabricate(:category)

        put "/admin/embeddable_hosts/#{embeddable_host.id}.json",
            params: {
              embeddable_host: {
                host: "test.com",
                category_id: category.id,
              },
            }

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "embeddable host update not allowed"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "embeddable host update not allowed"
    end
  end

  describe "#destroy" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "logs embeddable host destroy" do
        delete "/admin/embeddable_hosts/#{embeddable_host.id}.json", params: {}

        expect(response.status).to eq(200)
        expect(
          UserHistory.where(
            acting_user_id: admin.id,
            action: UserHistory.actions[:embeddable_host_destroy],
          ).exists?,
        ).to eq(true)
      end
    end

    shared_examples "embeddable host deletion not allowed" do
      it "prevents deletion with a 404 response" do
        delete "/admin/embeddable_hosts/#{embeddable_host.id}.json", params: {}

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "embeddable host deletion not allowed"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "embeddable host deletion not allowed"
    end
  end
end
