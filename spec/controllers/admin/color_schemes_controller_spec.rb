require 'rails_helper'

describe Admin::ColorSchemesController do
  it "is a subclass of AdminController" do
    expect(described_class < Admin::AdminController).to eq(true)
  end

  context "while logged in as an admin" do
    let!(:user) { log_in(:admin) }
    let(:valid_params) { { color_scheme: {
        name: 'Such Design',
        colors: [
          {name: 'primary', hex: 'FFBB00'},
          {name: 'secondary', hex: '888888'}
        ]
      }
    } }

    describe "index" do
      it "returns success" do
        xhr :get, :index
        expect(response).to be_success
      end

      it "returns JSON" do
        Fabricate(:color_scheme)
        xhr :get, :index
        expect(::JSON.parse(response.body)).to be_present
      end
    end

    describe "create" do
      it "returns success" do
        xhr :post, :create, valid_params
        expect(response).to be_success
      end

      it "returns JSON" do
        xhr :post, :create, valid_params
        expect(::JSON.parse(response.body)['id']).to be_present
      end

      it "returns failure with invalid params" do
        params = valid_params
        params[:color_scheme][:colors][0][:hex] = 'cool color please'
        xhr :post, :create, valid_params
        expect(response).not_to be_success
        expect(::JSON.parse(response.body)['errors']).to be_present
      end
    end

    describe "update" do
      let(:existing) { Fabricate(:color_scheme) }

      it "returns success" do
        ColorSchemeRevisor.expects(:revise).returns(existing)
        xhr :put, :update, valid_params.merge(id: existing.id)
        expect(response).to be_success
      end

      it "returns JSON" do
        ColorSchemeRevisor.expects(:revise).returns(existing)
        xhr :put, :update, valid_params.merge(id: existing.id)
        expect(::JSON.parse(response.body)['id']).to be_present
      end

      it "returns failure with invalid params" do
        color_scheme = Fabricate(:color_scheme)
        params = valid_params.merge(id: color_scheme.id)
        params[:color_scheme][:colors][0][:name] = color_scheme.colors.first.name
        params[:color_scheme][:colors][0][:hex] = 'cool color please'
        xhr :put, :update, params
        expect(response).not_to be_success
        expect(::JSON.parse(response.body)['errors']).to be_present
      end
    end

    describe "destroy" do
      let!(:existing) { Fabricate(:color_scheme) }

      it "returns success" do
        expect {
          xhr :delete, :destroy, id: existing.id
        }.to change { ColorScheme.count }.by(-1)
        expect(response).to be_success
      end
    end
  end
end
