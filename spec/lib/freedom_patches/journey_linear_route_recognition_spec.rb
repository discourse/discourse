# frozen_string_literal: true

RSpec.describe ActionDispatch::Journey::Router do
  let(:routes) do
    ActionDispatch::Routing::RouteSet.new.tap do |route_set|
      route_set.draw do
        get "/users/current", to: "users#current"
        get "/users/:username",
            to: "users#show",
            constraints: {
              username: RouteFormat.username,
              format: /json|html/,
            }
        get "/entries/:id(/:post_number)",
            to: "topics#show",
            constraints: {
              id: /\d+/,
              post_number: /\d+/,
            }
        get "/files/*path", to: "uploads#show", format: false
      end
    end
  end

  it "preserves dotted parameters and constrained formats" do
    expect(routes.recognize_path("/users/jane.doe.json")).to eq(
      controller: "users",
      action: "show",
      username: "jane.doe",
      format: "json",
    )
    expect(routes.recognize_path("/users/jane.doe")).to eq(
      controller: "users",
      action: "show",
      username: "jane.doe",
    )
  end

  it "preserves static route precedence" do
    expect(routes.recognize_path("/users/current")).to eq(controller: "users", action: "current")
  end

  it "preserves optional constrained segments" do
    expect(routes.recognize_path("/entries/12/3")).to eq(
      controller: "topics",
      action: "show",
      id: "12",
      post_number: "3",
    )
    expect(routes.recognize_path("/entries/12")).to eq(
      controller: "topics",
      action: "show",
      id: "12",
    )
  end

  it "preserves globs containing dots and slashes" do
    expect(routes.recognize_path("/files/a.b/c.json")).to eq(
      controller: "uploads",
      action: "show",
      path: "a.b/c.json",
    )
  end

  it "rejects invalid constrained paths and HTTP methods" do
    expect { routes.recognize_path("/entries/nope") }.to raise_error(ActionController::RoutingError)
    expect { routes.recognize_path("/users/jane", method: :post) }.to raise_error(
      ActionController::RoutingError,
    )
  end

  it "yields each matching route only once" do
    request = ActionDispatch::Request.new(Rack::MockRequest.env_for("/users/jane.doe.json"))
    matches = []

    routes.router.recognize(request) { |_route, parameters| matches << parameters }

    expect(matches).to eq(
      [{ controller: "users", action: "show", username: "jane.doe", format: "json" }],
    )
  end
end
