# frozen_string_literal: true

Rails.application.config.to_prepare do
  Categories::TypeRegistry.register(Categories::Types::Discussion)
end
