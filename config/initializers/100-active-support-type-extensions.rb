# frozen_string_literal: true

Rails.application.config.to_prepare do
  ActiveModel::Type.register(:array, ActiveSupportTypeExtensions::Array)
end
