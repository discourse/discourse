# frozen_string_literal: true

RSpec.describe Admin::UserFieldsController do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)

  describe "#create" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "creates a user field" do
        expect {
          post "/admin/config/user-fields.json",
               params: {
                 user_field: {
                   name: "hello",
                   description: "hello desc",
                   field_type: "text",
                   requirement: "on_signup",
                 },
               }

          expect(response.status).to eq(200)
        }.to change(UserField, :count).by(1)
      end

      it "creates a user field with options" do
        expect do
          post "/admin/config/user-fields.json",
               params: {
                 user_field: {
                   name: "hello",
                   description: "hello desc",
                   field_type: "dropdown",
                   options: %w[a b c],
                   requirement: "on_signup",
                 },
               }

          expect(response.status).to eq(200)
        end.to change(UserField, :count).by(1)

        expect(UserFieldOption.count).to eq(3)
      end
    end

    shared_examples "user field creation not allowed" do
      it "prevents creation with a 404 response" do
        expect do
          post "/admin/config/user-fields.json",
               params: {
                 user_field: {
                   name: "hello",
                   description: "hello desc",
                   field_type: "text",
                 },
               }
        end.not_to change { UserField.count }

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "user field creation not allowed"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "user field creation not allowed"
    end
  end

  describe "#index" do
    fab!(:user_field)

    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "returns a list of user fields" do
        get "/admin/config/user-fields.json"
        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["user_fields"]).to be_present
      end
    end

    shared_examples "user fields inaccessible" do
      it "denies access with a 404 response" do
        get "/admin/config/user-fields.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
        expect(response.parsed_body["user_fields"]).to be_nil
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "user fields inaccessible"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "user fields inaccessible"
    end
  end

  describe "#destroy" do
    fab!(:user_field)

    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "deletes the user field" do
        expect {
          delete "/admin/config/user-fields/#{user_field.id}.json"
          expect(response.status).to eq(200)
        }.to change(UserField, :count).by(-1)
      end
    end

    shared_examples "user field deletion not allowed" do
      it "prevents deletion with a 404 response" do
        expect do delete "/admin/config/user-fields/#{user_field.id}.json" end.not_to change {
          UserField.count
        }

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "user field deletion not allowed"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "user field deletion not allowed"
    end
  end

  describe "#update" do
    fab!(:user_field)

    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "updates the user field" do
        put "/admin/config/user-fields/#{user_field.id}.json",
            params: {
              user_field: {
                name: "fraggle",
                field_type: "confirm",
                description: "muppet",
                requirement: "optional",
              },
            }

        expect(response.status).to eq(200)
        expect(user_field.reload).to have_attributes(
          name: "fraggle",
          field_type: "confirm",
          required?: false,
        )
      end

      it "updates the user field options" do
        put "/admin/config/user-fields/#{user_field.id}.json",
            params: {
              user_field: {
                name: "fraggle",
                field_type: "dropdown",
                description: "muppet",
                options: %w[hello hello world],
              },
            }

        expect(response.status).to eq(200)
        user_field.reload
        expect(user_field.name).to eq("fraggle")
        expect(user_field.field_type).to eq("dropdown")
        expect(user_field.user_field_options.size).to eq(2)
      end

      it "keeps options when updating the user field" do
        put "/admin/config/user-fields/#{user_field.id}.json",
            params: {
              user_field: {
                name: "fraggle",
                field_type: "dropdown",
                description: "muppet",
                options: %w[hello hello world],
                position: 1,
              },
            }

        expect(response.status).to eq(200)
        user_field.reload
        expect(user_field.user_field_options.size).to eq(2)

        put "/admin/config/user-fields/#{user_field.id}.json",
            params: {
              user_field: {
                name: "fraggle",
                field_type: "dropdown",
                description: "muppet",
                position: 2,
              },
            }

        expect(response.status).to eq(200)
        user_field.reload
        expect(user_field.user_field_options.size).to eq(2)
      end

      it "removes directory column record if not public" do
        next_position = DirectoryColumn.maximum("position") + 1
        DirectoryColumn.create(
          user_field_id: user_field.id,
          enabled: false,
          type: DirectoryColumn.types[:user_field],
          position: next_position,
        )
        expect {
          put "/admin/config/user-fields/#{user_field.id}.json",
              params: {
                user_field: {
                  show_on_profile: false,
                  show_on_user_card: false,
                  searchable: true,
                },
              }
        }.to change { DirectoryColumn.count }.by(-1)
      end
    end

    shared_examples "user field update not allowed" do
      it "prevents updates with a 404 response" do
        user_field.reload
        original_name = user_field.name

        put "/admin/config/user-fields/#{user_field.id}.json",
            params: {
              user_field: {
                name: "fraggle",
                field_type: "confirm",
                description: "muppet",
              },
            }

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))

        user_field.reload
        expect(user_field.name).to eq(original_name)
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "user field update not allowed"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "user field update not allowed"
    end
  end
end
