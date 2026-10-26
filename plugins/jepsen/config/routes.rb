# frozen_string_literal: true

Jepsen::Engine.routes.draw { get "/examples" => "examples#index" }
