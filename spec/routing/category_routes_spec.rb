# frozen_string_literal: true

RSpec.describe "Category routes" do
  it "constrains category slug with id" do
    with_routing do |set|
      set.draw do
        mount Discourse::Application => "/"

        # an example of plugin-added routes
        get "/c/:category_slug_path_with_id/extra/awesome/path" => "posts#show",
            :constraints => {
              category_slug_path_with_id: RouteFormat.category_slug_path_with_id,
            }
        get "/c/*category_slug_path_with_id/bloop" => "posts#index",
            :constraints => {
              category_slug_path_with_id: RouteFormat.category_slug_path_with_id,
            }
      end

      # core route still works
      expect(get("/c/test-category/3/all")).to route_to(
        {
          controller: "list",
          action: "category_default",
          category_slug_path_with_id: "test-category/3",
        },
      )

      # plugin routes work
      expect(get("/c/test-category/3/bloop")).to route_to(
        { controller: "posts", action: "index", category_slug_path_with_id: "test-category/3" },
      )
      expect(get("/c/test-category/3/extra/awesome/path")).to route_to(
        { controller: "posts", action: "show", category_slug_path_with_id: "test-category/3" },
      )

      # non-existent routes still 404
      expect(get("/c/test-category/3/does/not/exist")).to_not be_routable
    end
  end
end
