# frozen_string_literal: true

Rhodes::Engine.routes.draw { get "/examples" => "examples#index" }

Discourse::Application.routes.draw { mount ::Rhodes::Engine, at: "rhodes" }
