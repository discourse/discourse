# frozen_string_literal: true

require 'rails_helper'

describe Admin::UserFieldsController do
  it "is a subclass of AdminController" do
    expect(Admin::UserFieldsController < Admin::AdminController).to eq(true)
  end

  context "when logged in" do
    fab!(:admin) { Fabricate(:admin) }

    before do
      sign_in(admin)
    end

    describe '#create' do
      it "creates a user field" do
        expect {
          post "/admin/customize/user_fields.json", params: {
            user_field: { name: 'hello', description: 'hello desc', field_type: 'text' }
          }

          expect(response.status).to eq(200)
        }.to change(UserField, :count).by(1)
      end

      it "creates a user field with options" do
        expect do
          post "/admin/customize/user_fields.json", params: {
            user_field: {
              name: 'hello',
              description: 'hello desc',
              field_type: 'dropdown',
              options: ['a', 'b', 'c']
            }
          }

          expect(response.status).to eq(200)
        end.to change(UserField, :count).by(1)

        expect(UserFieldOption.count).to eq(3)
      end
    end

    describe '#index' do
      fab!(:user_field) { Fabricate(:user_field) }

      it "returns a list of user fields" do
        get "/admin/customize/user_fields.json"
        expect(response.status).to eq(200)
        json = ::JSON.parse(response.body)
        expect(json['user_fields']).to be_present
      end
    end

    describe '#destroy' do
      fab!(:user_field) { Fabricate(:user_field) }

      it "deletes the user field" do
        expect {
          delete "/admin/customize/user_fields/#{user_field.id}.json"
          expect(response.status).to eq(200)
        }.to change(UserField, :count).by(-1)
      end
    end

    describe '#update' do
      fab!(:user_field) { Fabricate(:user_field) }

      it "updates the user field" do
        put "/admin/customize/user_fields/#{user_field.id}.json", params: {
          user_field: { name: 'fraggle', field_type: 'confirm', description: 'muppet' }
        }

        expect(response.status).to eq(200)
        user_field.reload
        expect(user_field.name).to eq('fraggle')
        expect(user_field.field_type).to eq('confirm')
      end

      it "updates the user field options" do
        put "/admin/customize/user_fields/#{user_field.id}.json", params: {
          user_field: {
            name: 'fraggle',
            field_type: 'dropdown',
            description: 'muppet',
            options: ['hello', 'hello', 'world']
          }
        }

        expect(response.status).to eq(200)
        user_field.reload
        expect(user_field.name).to eq('fraggle')
        expect(user_field.field_type).to eq('dropdown')
        expect(user_field.user_field_options.size).to eq(2)
      end

      it "keeps options when updating the user field" do
        put "/admin/customize/user_fields/#{user_field.id}.json", params: {
          user_field: {
            name: 'fraggle',
            field_type: 'dropdown',
            description: 'muppet',
            options: ['hello', 'hello', 'world'],
            position: 1
          }
        }

        expect(response.status).to eq(200)
        user_field.reload
        expect(user_field.user_field_options.size).to eq(2)

        put "/admin/customize/user_fields/#{user_field.id}.json", params: {
          user_field: {
            name: 'fraggle',
            field_type: 'dropdown',
            description: 'muppet',
            position: 2
          }
        }

        expect(response.status).to eq(200)
        user_field.reload
        expect(user_field.user_field_options.size).to eq(2)
      end
    end
  end
end
