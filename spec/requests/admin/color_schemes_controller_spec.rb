require 'rails_helper'

describe Admin::ColorSchemesController do
  it "is a subclass of AdminController" do
    expect(described_class < Admin::AdminController).to eq(true)
  end

  context "while logged in as an admin" do
    let(:admin) { Fabricate(:admin) }
    let(:valid_params) { { color_scheme: {
        name: 'Such Design',
        colors: [
          { name: 'primary', hex: 'FFBB00' },
          { name: 'secondary', hex: '888888' }
        ]
      }
    } }

    before do
      sign_in(admin)
    end

    describe "#index" do
      it "returns JSON" do
        scheme_name = Fabricate(:color_scheme).name
        get "/admin/color_schemes.json"

        expect(response.status).to eq(200)
        schemes = JSON.parse(response.body).map { |scheme| scheme["name"] }
        expect(schemes).to include(scheme_name)
      end
    end

    describe "#create" do
      it "returns JSON" do
        post "/admin/color_schemes.json", params: valid_params

        expect(response.status).to eq(200)
        expect(::JSON.parse(response.body)['id']).to be_present
      end

      it "returns failure with invalid params" do
        params = valid_params
        params[:color_scheme][:colors][0][:hex] = 'cool color please'

        post "/admin/color_schemes.json", params: valid_params

        expect(response.status).to eq(422)
        expect(::JSON.parse(response.body)['errors']).to be_present
      end
    end

    describe "#update" do
      let(:existing) { Fabricate(:color_scheme) }

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
        params[:color_scheme][:colors][0][:hex] = 'cool color please'

        put "/admin/color_schemes/#{color_scheme.id}.json", params: params

        expect(response.status).to eq(422)
        expect(::JSON.parse(response.body)['errors']).to be_present
      end
    end

    describe "#destroy" do
      let!(:existing) { Fabricate(:color_scheme) }

      it "returns success" do
        expect {
          delete "/admin/color_schemes/#{existing.id}.json"
        }.to change { ColorScheme.count }.by(-1)
        expect(response.status).to eq(200)
      end
    end
  end
end
