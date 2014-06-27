require "spec_helper"

describe CategoriesController do
  describe "create" do

    it "requires the user to be logged in" do
      lambda { xhr :post, :create }.should raise_error(Discourse::NotLoggedIn)
    end

    describe "logged in" do
      before do
        @user = log_in(:admin)
      end

      it "raises an exception when they don't have permission to create it" do
        Guardian.any_instance.expects(:can_create?).with(Category, nil).returns(false)
        xhr :post, :create, name: 'hello', color: 'ff0', text_color: 'fff'
        response.should be_forbidden
      end

      it "raises an exception when the name is missing" do
        lambda { xhr :post, :create, color: "ff0", text_color: "fff" }.should raise_error(ActionController::ParameterMissing)
      end

      it "raises an exception when the color is missing" do
        lambda { xhr :post, :create, name: "hello", text_color: "fff" }.should raise_error(ActionController::ParameterMissing)
      end

      it "raises an exception when the text color is missing" do
        lambda { xhr :post, :create, name: "hello", color: "ff0" }.should raise_error(ActionController::ParameterMissing)
      end

      describe "failure" do
        before do
          @category = Fabricate(:category, user: @user)
          xhr :post, :create, name: @category.name, color: "ff0", text_color: "fff"
        end

        it { should_not respond_with(:success) }

        it "returns errors on a duplicate category name" do
          response.status.should == 422
        end
      end


      describe "success" do
        it "works" do
          readonly = CategoryGroup.permission_types[:readonly]
          create_post = CategoryGroup.permission_types[:create_post]

          xhr :post, :create, name: "hello", color: "ff0", text_color: "fff",
                              auto_close_hours: 72,
                              permissions: {
                                "everyone" => readonly,
                                "staff" => create_post
                              }

          response.status.should == 200
          category = Category.find_by(name: "hello")
          category.category_groups.map{|g| [g.group_id, g.permission_type]}.sort.should == [
            [Group[:everyone].id, readonly],[Group[:staff].id,create_post]
          ]
          category.name.should == "hello"
          category.color.should == "ff0"
          category.auto_close_hours.should == 72
        end
      end
    end
  end

  describe "destroy" do

    it "requires the user to be logged in" do
      lambda { xhr :delete, :destroy, id: "category"}.should raise_error(Discourse::NotLoggedIn)
    end

    describe "logged in" do
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

  describe "upload" do
    it "requires the user to be logged in" do
      lambda { xhr :post, :upload, image_type: 'logo'}.should raise_error(Discourse::NotLoggedIn)
    end

    describe "logged in" do
      let!(:user) { log_in(:admin) }

      let(:logo) { File.new("#{Rails.root}/spec/fixtures/images/logo.png") }
      let(:upload) do
        ActionDispatch::Http::UploadedFile.new({ filename: 'logo.png', tempfile: logo })
      end

      it "raises an error when you don't have permission to upload" do
        Guardian.any_instance.expects(:can_create?).with(Category).returns(false)
        xhr :post, :upload, image_type: 'logo', file: upload
        response.should be_forbidden
      end

      it "requires the `image_type` param" do
        -> { xhr :post, :upload }.should raise_error(ActionController::ParameterMissing)
      end

      it "calls Upload.create_for" do
        Upload.expects(:create_for).returns(Upload.new)
        xhr :post, :upload, image_type: 'logo', file: upload
        response.should be_success
      end
    end
  end

  describe "update" do

    it "requires the user to be logged in" do
      lambda { xhr :put, :update, id: 'category'}.should raise_error(Discourse::NotLoggedIn)
    end


    describe "logged in" do
      let(:valid_attrs) { {id: @category.id, name: "hello", color: "ff0", text_color: "fff"} }

      before do
        @user = log_in(:admin)
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

      describe "failure" do
        before do
          @other_category = Fabricate(:category, name: "Other", user: @user )
          xhr :put, :update, id: @category.id, name: @other_category.name, color: "ff0", text_color: "fff"
        end

        it "returns errors on a duplicate category name" do
          response.should_not be_success
        end

        it "returns errors on a duplicate category name" do
          response.code.to_i.should == 422
        end
      end

      describe "success" do

        it "updates the group correctly" do
          readonly = CategoryGroup.permission_types[:readonly]
          create_post = CategoryGroup.permission_types[:create_post]

          xhr :put, :update, id: @category.id, name: "hello", color: "ff0", text_color: "fff",
                              auto_close_hours: 72,
                              permissions: {
                                "everyone" => readonly,
                                "staff" => create_post
                              }

          response.status.should == 200
          @category.reload
          @category.category_groups.map{|g| [g.group_id, g.permission_type]}.sort.should == [
            [Group[:everyone].id, readonly],[Group[:staff].id,create_post]
          ]
          @category.name.should == "hello"
          @category.color.should == "ff0"
          @category.auto_close_hours.should == 72
        end
      end
    end


  end

end
