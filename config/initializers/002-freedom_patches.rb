# frozen_string_literal: true

RUN_WITHOUT_PREPARE = ["#{Rails.root}/lib/freedom_patches/rails_multisite.rb"]
RUN_WITHOUT_PREPARE.each { |path| require(path) }

Rails.application.reloader.to_prepare do
  Dir["#{Rails.root}/lib/freedom_patches/*.rb"].each do |f|
    next if RUN_WITHOUT_PREPARE.any? { |path| path == f }
    require(f)
  end
end
