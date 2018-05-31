require "rails_helper"

describe CategoriesController do
  describe "create" do

    it "requires the user to be logged in" do
      post :create, format: :json
      expect(response.status).to eq(403)
    end

    describe "logged in" do
      before do
        SiteSetting.queue_jobs = false
        @user = log_in(:admin)
      end

      it "raises an exception when they don't have permission to create it" do
        Guardian.any_instance.expects(:can_create?).with(Category, nil).returns(false)
        post :create, params: {
          name: 'hello', color: 'ff0', text_color: 'fff'
        }, format: :json

        expect(response).to be_forbidden
      end

      it "raises an exception when the name is missing" do
        expect do
          post :create, params: { color: "ff0", text_color: "fff" }, format: :json
        end.to raise_error(ActionController::ParameterMissing)
      end

      it "raises an exception when the color is missing" do
        expect do
          post :create, params: { name: "hello", text_color: "fff" }, format: :json
        end.to raise_error(ActionController::ParameterMissing)
      end

      it "raises an exception when the text color is missing" do
        expect do
          post :create, params: { name: "hello", color: "ff0" }, format: :json
        end.to raise_error(ActionController::ParameterMissing)
      end

      describe "failure" do
        before do
          @category = Fabricate(:category, user: @user)

          post :create, params: {
            name: @category.name, color: "ff0", text_color: "fff"
          }, format: :json
        end

        it "returns errors on a duplicate category name" do
          expect(response.status).to eq(422)
        end
      end

      describe "success" do
        it "works" do
          readonly = CategoryGroup.permission_types[:readonly]
          create_post = CategoryGroup.permission_types[:create_post]

          post :create, params: {
            name: "hello",
            color: "ff0",
            text_color: "fff",
            slug: "hello-cat",
            auto_close_hours: 72,
            permissions: {
              "everyone" => readonly,
              "staff" => create_post
            }
          }, format: :json

          expect(response.status).to eq(200)
          category = Category.find_by(name: "hello")
          expect(category.category_groups.map { |g| [g.group_id, g.permission_type] }.sort).to eq([
            [Group[:everyone].id, readonly], [Group[:staff].id, create_post]
          ])
          expect(category.name).to eq("hello")
          expect(category.slug).to eq("hello-cat")
          expect(category.color).to eq("ff0")
          expect(category.auto_close_hours).to eq(72)
          expect(UserHistory.count).to eq(4) # 1 + 3 (bootstrap mode)
        end
      end
    end
  end

  describe "destroy" do

    it "requires the user to be logged in" do
      delete :destroy, params: { id: "category" }, format: :json
      expect(response.status).to eq(403)
    end

    describe "logged in" do
      before do
        @user = log_in
        @category = Fabricate(:category, user: @user)
      end

      it "raises an exception if they don't have permission to delete it" do
        Guardian.any_instance.expects(:can_delete_category?).returns(false)
        delete :destroy, params: { id: @category.slug }, format: :json
        expect(response).to be_forbidden
      end

      it "deletes the record" do
        Guardian.any_instance.expects(:can_delete_category?).returns(true)
        expect do
          delete :destroy, params: { id: @category.slug }, format: :json
        end.to change(Category, :count).by(-1)

        expect(UserHistory.count).to eq(1)
      end
    end

  end

  describe "reorder" do
    it "reorders the categories" do
      admin = log_in(:admin)

      c1 = Fabricate(:category)
      c2 = Fabricate(:category)
      c3 = Fabricate(:category)
      c4 = Fabricate(:category)
      if c3.id < c2.id
        tmp = c3; c2 = c3; c3 = tmp;
      end
      c1.position = 8
      c2.position = 6
      c3.position = 7
      c4.position = 5

      payload = {}
      payload[c1.id] = 4
      payload[c2.id] = 6
      payload[c3.id] = 6
      payload[c4.id] = 5

      post :reorder, params: { mapping: MultiJson.dump(payload) }, format: :json

      SiteSetting.fixed_category_positions = true
      list = CategoryList.new(Guardian.new(admin))

      expect(list.categories).to eq([
        Category.find(SiteSetting.uncategorized_category_id),
        c1,
        c4,
        c2,
        c3
      ])
    end
  end

  describe "update" do
    before do
      SiteSetting.queue_jobs = false
    end

    it "requires the user to be logged in" do
      put :update, params: { id: 'category' }, format: :json
      expect(response.status).to eq(403)
    end

    describe "logged in" do
      let(:valid_attrs) { { id: @category.id, name: "hello", color: "ff0", text_color: "fff" } }

      before do
        @user = log_in(:admin)
        @category = Fabricate(:category, user: @user)
      end

      it "raises an exception if they don't have permission to edit it" do
        Guardian.any_instance.expects(:can_edit?).returns(false)
        put :update, params: {
          id: @category.slug,
          name: 'hello',
          color: 'ff0',
          text_color: 'fff'
        }, format: :json

        expect(response).to be_forbidden
      end

      it "requires a name" do
        expect do
          put :update, params: {
            id: @category.slug,
            color: 'fff',
            text_color: '0ff',
          }, format: :json
        end.to raise_error(ActionController::ParameterMissing)
      end

      it "requires a color" do
        expect do
          put :update, params: {
            id: @category.slug,
            name: 'asdf',
            text_color: '0ff',
          }, format: :json
        end.to raise_error(ActionController::ParameterMissing)
      end

      it "requires a text color" do
        expect do
          put :update,
            params: { id: @category.slug, name: 'asdf', color: 'fff' },
            format: :json
        end.to raise_error(ActionController::ParameterMissing)
      end

      describe "failure" do
        before do
          @other_category = Fabricate(:category, name: "Other", user: @user)

          put :update, params: {
            id: @category.id,
            name: @other_category.name,
            color: "ff0",
            text_color: "fff",
          }, format: :json
        end

        it "returns errors on a duplicate category name" do
          expect(response).not_to be_success
        end

        it "returns errors on a duplicate category name" do
          expect(response.code.to_i).to eq(422)
        end
      end

      it "returns 422 if email_in address is already in use for other category" do
        @other_category = Fabricate(:category, name: "Other", email_in: "mail@examle.com")

        put :update, params: {
          id: @category.id,
          name: "Email",
          email_in: "mail@examle.com",
          color: "ff0",
          text_color: "fff",
        }, format: :json

        expect(response).not_to be_success
        expect(response.code.to_i).to eq(422)
      end

      describe "success" do

        it "updates the group correctly" do
          readonly = CategoryGroup.permission_types[:readonly]
          create_post = CategoryGroup.permission_types[:create_post]

          put :update, params: {
            id: @category.id,
            name: "hello",
            color: "ff0",
            text_color: "fff",
            slug: "hello-category",
            auto_close_hours: 72,
            permissions: {
              "everyone" => readonly,
              "staff" => create_post
            },
            custom_fields: {
              "dancing" => "frogs"
            },
          }, format: :json

          expect(response.status).to eq(200)
          @category.reload
          expect(@category.category_groups.map { |g| [g.group_id, g.permission_type] }.sort).to eq([
            [Group[:everyone].id, readonly], [Group[:staff].id, create_post]
          ])
          expect(@category.name).to eq("hello")
          expect(@category.slug).to eq("hello-category")
          expect(@category.color).to eq("ff0")
          expect(@category.auto_close_hours).to eq(72)
          expect(@category.custom_fields).to eq("dancing" => "frogs")
        end

        it 'logs the changes correctly' do
          @category.update!(permissions: { "admins" => CategoryGroup.permission_types[:create_post] })

          put :update, params: {
            id: @category.id,
            name: 'new name',
            color: @category.color,
            text_color: @category.text_color,
            slug: @category.slug,
            permissions: {
              "everyone" => CategoryGroup.permission_types[:create_post]
            },
          }, format: :json

          expect(UserHistory.count).to eq(5) # 2 + 3 (bootstrap mode)
        end
      end
    end

  end

  describe 'update_slug' do
    it 'requires the user to be logged in' do
      put :update_slug, params: { category_id: 'category' }, format: :json
      expect(response.status).to eq(403)
    end

    describe 'logged in' do
      let(:valid_attrs) { { id: @category.id, slug: 'fff' } }

      before do
        @user = log_in(:admin)
        @category = Fabricate(:happy_category, user: @user)
      end

      it 'rejects blank' do
        put :update_slug, params: { category_id: @category.id, slug: nil }, format: :json
        expect(response.status).to eq(422)
      end

      it 'accepts valid custom slug' do
        put :update_slug,
          params: { category_id: @category.id, slug: 'valid-slug' },
          format: :json

        expect(response).to be_success
        expect(@category.reload.slug).to eq('valid-slug')
      end

      it 'accepts not well formed custom slug' do
        put :update_slug,
          params: { category_id: @category.id, slug: ' valid slug' },
          format: :json

        expect(response).to be_success
        expect(@category.reload.slug).to eq('valid-slug')
      end

      it 'accepts and sanitize custom slug when the slug generation method is not ascii' do
        SiteSetting.slug_generation_method = 'none'
        put :update_slug,
          params: { category_id: @category.id, slug: ' another !_ slug @' },
          format: :json

        expect(response).to be_success
        expect(@category.reload.slug).to eq('another-slug')
        SiteSetting.slug_generation_method = 'ascii'
      end

      it 'rejects invalid custom slug' do
        put :update_slug,
          params: { category_id: @category.id, slug: '  ' },
          format: :json

        expect(response.status).to eq(422)
      end
    end
  end
end
