# frozen_string_literal: true

Rails.application.reloader.to_prepare do
  Dir["#{Rails.root}/lib/freedom_patches/*.rb"].each do |f|
    require(f)
  end
end
