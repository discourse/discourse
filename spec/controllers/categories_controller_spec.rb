require 'spec_helper'

describe CategoriesController do
  describe 'create' do

    it 'requires the user to be logged in' do
      lambda { xhr :post, :create }.should raise_error(Discourse::NotLoggedIn)
    end

    describe 'logged in' do
      before do
        @user = log_in(:moderator)
      end

      it "raises an exception when they don't have permission to create it" do
        Guardian.any_instance.expects(:can_create?).with(Category, nil).returns(false)
        xhr :post, :create, name: 'hello', color: 'ff0', text_color: 'fff'
        response.should be_forbidden
      end

      it 'raises an exception when the name is missing' do
        lambda { xhr :post, :create, color: 'ff0', text_color: 'fff' }.should raise_error(ActionController::ParameterMissing)
      end

      it 'raises an exception when the color is missing' do
        lambda { xhr :post, :create, name: 'hello', text_color: 'fff' }.should raise_error(ActionController::ParameterMissing)
      end

      it 'raises an exception when the text color is missing' do
        lambda { xhr :post, :create, name: 'hello', color: 'ff0' }.should raise_error(ActionController::ParameterMissing)
      end

      describe 'failure' do
        before do
          @category = Fabricate(:category, user: @user)
          xhr :post, :create, name: @category.name, color: 'ff0', text_color: 'fff'
        end

        it { should_not respond_with(:success) }

        it 'returns errors on a duplicate category name' do
          response.code.to_i.should == 422
        end
      end


      describe 'success' do
        before do
          xhr :post, :create, name: 'hello', color: 'ff0', text_color: 'fff'
        end

        it 'creates a category' do
          Category.count.should == 1
        end

        it { should respond_with(:success) }

      end

    end
  end

  describe 'destroy' do

    it 'requires the user to be logged in' do
      lambda { xhr :delete, :destroy, id: 'category'}.should raise_error(Discourse::NotLoggedIn)
    end

    describe 'logged in' do
      before do
        @user = log_in
        @category = Fabricate(:category, user: @user)
      end

      it "raises an exception if they don't have permission to delete it" do
        Guardian.any_instance.expects(:can_delete_category?).returns(false)
        xhr :delete, :destroy, id: @category.slug
        response.should be_forbidden
      end

      it "deletes the record" do
        Guardian.any_instance.expects(:can_delete_category?).returns(true)
        lambda { xhr :delete, :destroy, id: @category.slug}.should change(Category, :count).by(-1)
      end
    end

  end

  describe 'update' do

    it 'requires the user to be logged in' do
      lambda { xhr :put, :update, id: 'category'}.should raise_error(Discourse::NotLoggedIn)
    end


    describe 'logged in' do
      before do
        @user = log_in(:moderator)
        @category = Fabricate(:category, user: @user)
      end

      it "raises an exception if they don't have permission to edit it" do
        Guardian.any_instance.expects(:can_edit?).returns(false)
        xhr :put, :update, id: @category.slug, name: 'hello', color: 'ff0', text_color: 'fff'
        response.should be_forbidden
      end

      it "requires a name" do
        lambda { xhr :put, :update, id: @category.slug, color: 'fff', text_color: '0ff' }.should raise_error(ActionController::ParameterMissing)
      end

      it "requires a color" do
        lambda { xhr :put, :update, id: @category.slug, name: 'asdf', text_color: '0ff' }.should raise_error(ActionController::ParameterMissing)
      end

      it "requires a text color" do
        lambda { xhr :put, :update, id: @category.slug, name: 'asdf', color: 'fff' }.should raise_error(ActionController::ParameterMissing)
      end

      describe 'failure' do
        before do
          @other_category = Fabricate(:category, name: 'Other', user: @user )
          xhr :put, :update, id: @category.id, name: @other_category.name, color: 'ff0', text_color: 'fff'
        end

        it 'returns errors on a duplicate category name' do
          response.should_not be_success
        end

        it 'returns errors on a duplicate category name' do
          response.code.to_i.should == 422
        end
      end

      describe 'success' do
        before do
          # might as well test this as well
          @category.allow(Group[:admins])
          @category.save

          xhr :put, :update, id: @category.id, name: 'science', color: '000', text_color: '0ff', group_names: Group[:staff].name, secure: 'true'
          @category.reload
        end

        it 'updates the group correctly' do
          @category.name.should == 'science'
          @category.color.should == '000'
          @category.text_color.should == '0ff'
          @category.secure?.should be_true
          @category.groups.count.should == 1
        end
      end
    end


  end

end
