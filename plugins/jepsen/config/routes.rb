# frozen_string_literal: true

Jepsen::Engine.routes.draw { get "/examples" => "examples#index" }

Discourse::Application.routes.draw { mount ::Jepsen::Engine, at: "jepsen" }
