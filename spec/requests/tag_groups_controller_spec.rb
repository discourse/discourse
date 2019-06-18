# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TagGroupsController do
  fab!(:user) { Fabricate(:user) }
  fab!(:tag_group) { Fabricate(:tag_group) }

  describe '#index' do
    describe 'for a non staff user' do
      it 'should not be accessible' do
        get "/tag_groups.json"

        expect(response.status).to eq(404)

        sign_in(user)
        get "/tag_groups.json"

        expect(response.status).to eq(404)
      end
    end

    describe 'for a staff user' do
      fab!(:admin) { Fabricate(:admin) }

      before do
        sign_in(admin)
      end

      it "should return the right response" do
        tag_group

        get "/tag_groups.json"

        expect(response.status).to eq(200)

        tag_groups = JSON.parse(response.body)["tag_groups"]

        expect(tag_groups.count).to eq(1)
        expect(tag_groups.first["id"]).to eq(tag_group.id)
      end
    end
  end
end
