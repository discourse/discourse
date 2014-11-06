require 'spec_helper'

describe Admin::UserFieldsController do

  it "is a subclass of AdminController" do
    (Admin::ApiController < Admin::AdminController).should == true
  end

  context "when logged in" do
    let!(:user) { log_in(:admin) }

    context '.create' do
      it "creates a user field" do
        -> {
          xhr :post, :create, {user_field: {name: 'hello', description: 'hello desc', field_type: 'text'} }
          response.should be_success
        }.should change(UserField, :count).by(1)
      end
    end

    context '.index' do
      let!(:user_field) { Fabricate(:user_field) }

      it "returns a list of user fields" do
        xhr :get, :index
        response.should be_success
        json = ::JSON.parse(response.body)
        json['user_fields'].should be_present
      end
    end

    context '.destroy' do
      let!(:user_field) { Fabricate(:user_field) }

      it "deletes the user field" do
        -> {
          xhr :delete, :destroy, id: user_field.id
          response.should be_success
        }.should change(UserField, :count).by(-1)
      end
    end

    context '.update' do
      let!(:user_field) { Fabricate(:user_field) }

      it "updates the user field" do
        xhr :put, :update, id: user_field.id, user_field: {name: 'fraggle', field_type: 'confirm', description: 'muppet'}
        response.should be_success
        user_field.reload
        user_field.name.should == 'fraggle'
        user_field.field_type.should == 'confirm'
      end
    end
  end

end

