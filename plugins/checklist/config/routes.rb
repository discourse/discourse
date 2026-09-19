# frozen_string_literal: true

Checklist::Engine.routes.draw { put "/toggle" => "checkboxes#toggle" }
