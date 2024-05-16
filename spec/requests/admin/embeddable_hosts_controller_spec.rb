# frozen_string_literal: true

RSpec.describe Admin::EmbeddableHostsController do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)
  fab!(:embeddable_host)

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

      it "creates an embeddable host with associated tags" do
        tag1 = Fabricate(:tag, name: "tag1")
        tag2 = Fabricate(:tag, name: "tag2")

        post "/admin/embeddable_hosts.json",
             params: {
               embeddable_host: {
                 host: "example.com",
                 tags: %w[tag1 tag2],
               },
             }

        expect(response.status).to eq(200)
        expect(EmbeddableHost.last.tags).to contain_exactly(tag1, tag2)
      end

      it "updates an embeddable host with associated tags" do
        tag1 = Fabricate(:tag, name: "newTag1")
        tag2 = Fabricate(:tag, name: "newTag2")

        put "/admin/embeddable_hosts/#{embeddable_host.id}.json",
            params: {
              embeddable_host: {
                host: "updated-example.com",
                tags: %w[newTag1 newTag2],
              },
            }

        expect(response.status).to eq(200)
        expect(EmbeddableHost.find(embeddable_host.id).tags).to contain_exactly(tag1, tag2)
      end

      it "creates an embeddable host with an associated author" do
        user = Fabricate(:user, username: "johndoe")

        post "/admin/embeddable_hosts.json",
             params: {
               embeddable_host: {
                 host: "example.com",
                 user: "johndoe",
               },
             }

        expect(response.status).to eq(200)
        expect(EmbeddableHost.last.user).to eq(user)
      end

      it "updates an embeddable host with a new author" do
        new_user = Fabricate(:user, username: "johndoe")

        put "/admin/embeddable_hosts/#{embeddable_host.id}.json",
            params: {
              embeddable_host: {
                host: "updated-example.com",
                user: "johndoe",
              },
            }

        expect(response.status).to eq(200)
        expect(EmbeddableHost.find(embeddable_host.id).user).to eq(new_user)
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
