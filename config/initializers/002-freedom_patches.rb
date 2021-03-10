# frozen_string_literal: true

Dir["#{Rails.root}/lib/freedom_patches/*.rb"].each do |f|
  Rails.application.reloader.to_prepare do
    require(f)
  end
end
