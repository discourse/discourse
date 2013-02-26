require 'spec_helper'

describe RequestAccessController do

  context '.new' do
    it "sets a default return path" do
      get :new
      assigns(:return_path).should == "/"
    end

    it "assigns the return path we provide" do
      get :new, return_path: '/asdf'
      assigns(:return_path).should == "/asdf"
    end
  end


  context '.create' do

    context 'without an invalid password' do
      before do
        post :create, password: 'asdf'
      end

      it "adds a flash" do
        flash[:error].should be_present
      end

      it "doesn't set the cookie" do
        cookies[:_access].should be_blank
      end
    end

    context 'with a valid password' do
      before do
        SiteSetting.stubs(:access_password).returns 'test password'
        post :create, password: 'test password', return_path: '/the-path'
      end

      it 'creates the cookie' do
        cookies[:_access].should == 'test password'
      end

      it 'redirects to the return path' do
        response.should redirect_to('/the-path')
      end

      it 'sets no flash error' do
        flash[:error].should be_blank
      end

    end

  end

end
