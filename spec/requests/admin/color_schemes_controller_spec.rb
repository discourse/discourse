# frozen_string_literal: true

RSpec.describe Admin::ColorSchemesController do
  fab!(:admin) { Fabricate(:admin) }
  fab!(:moderator) { Fabricate(:moderator) }
  fab!(:user) { Fabricate(:user) }

  let(:valid_params) do
    {
      color_scheme: {
        name: "Such Design",
        colors: [{ name: "primary", hex: "FFBB00" }, { name: "secondary", hex: "888888" }],
      },
    }
  end

  describe "#index" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "returns JSON" do
        scheme_name = Fabricate(:color_scheme).name
        get "/admin/color_schemes.json"

        expect(response.status).to eq(200)
        scheme_names = response.parsed_body.map { |scheme| scheme["name"] }
        scheme_colors = response.parsed_body[0]["colors"]
        base_scheme_colors = ColorScheme.base.colors

        expect(scheme_names).to include(scheme_name)
        expect(scheme_colors[0]["name"]).to eq(base_scheme_colors[0].name)
        expect(scheme_colors[0]["hex"]).to eq(base_scheme_colors[0].hex)
      end

      it "serializes default colors even when not present in database" do
        scheme = ColorScheme.create_from_base({ name: "my color scheme" })
        scheme.colors.find_by(name: "primary").destroy
        scheme_name = scheme.name

        get "/admin/color_schemes.json"
        expect(response.status).to eq(200)

        serialized_scheme = response.parsed_body.find { |s| s["name"] == "my color scheme" }
        scheme_colors = serialized_scheme["colors"]
        expect(scheme_colors[0]["name"]).to eq("primary")
        expect(scheme_colors[0]["hex"]).to eq(scheme.resolved_colors["primary"])
      end
    end

    shared_examples "color schemes inaccessible" do
      it "denies access with a 404 response" do
        get "/admin/color_schemes.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "color schemes inaccessible"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "color schemes inaccessible"
    end
  end

  describe "#create" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "returns JSON" do
        post "/admin/color_schemes.json", params: valid_params

        expect(response.status).to eq(200)
        expect(response.parsed_body["id"]).to be_present
      end

      it "returns failure with invalid params" do
        params = valid_params
        params[:color_scheme][:colors][0][:hex] = "cool color please"

        post "/admin/color_schemes.json", params: valid_params

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to be_present
      end
    end

    shared_examples "color scheme creation not allowed" do
      it "prevents creation with a 404 response" do
        params = valid_params
        params[:color_scheme][:colors][0][:hex] = "cool color please"

        expect do post "/admin/color_schemes.json", params: valid_params end.not_to change {
          ColorScheme.count
        }

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "color scheme creation not allowed"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "color scheme creation not allowed"
    end
  end

  describe "#update" do
    fab!(:existing) { Fabricate(:color_scheme) }

    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "returns success" do
        put "/admin/color_schemes/#{existing.id}.json", params: valid_params
        expect(response.status).to eq(200)

        existing.reload
        new_colors = valid_params[:color_scheme][:colors]
        updated_colors = existing.colors.map { |color| { name: color.name, hex: color.hex } }

        expect(new_colors & updated_colors).to eq(new_colors)
        expect(existing.name).to eq(valid_params[:color_scheme][:name])
      end

      it "returns failure with invalid params" do
        color_scheme = Fabricate(:color_scheme)
        params = valid_params

        params[:color_scheme][:colors][0][:name] = color_scheme.colors.first.name
        params[:color_scheme][:colors][0][:hex] = "cool color please"

        put "/admin/color_schemes/#{color_scheme.id}.json", params: params

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to be_present
      end
    end

    shared_examples "color scheme update not allowed" do
      it "prevents update with a 404 response" do
        put "/admin/color_schemes/#{existing.id}.json", params: valid_params

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "color scheme update not allowed"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "color scheme update not allowed"
    end
  end

  describe "#destroy" do
    fab!(:existing) { Fabricate(:color_scheme) }

    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "returns success" do
        expect { delete "/admin/color_schemes/#{existing.id}.json" }.to change {
          ColorScheme.count
        }.by(-1)
        expect(response.status).to eq(200)
      end
    end

    shared_examples "color scheme deletion not allowed" do
      it "prevents deletion with a 404 response" do
        delete "/admin/color_schemes/#{existing.id}.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "color scheme deletion not allowed"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "color scheme deletion not allowed"
    end
  end
end
