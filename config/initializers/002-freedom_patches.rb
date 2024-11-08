# frozen_string_literal: true

# Multisite freedom patch defines RailsMultisite::DiscoursePatches.config which is used  by 200-first_middlewares.rb
# Therefore it can not be postponed with .to_prepare
RUN_WITHOUT_PREPARE = [
  "#{Rails.root}/lib/freedom_patches/rails_multisite.rb",
  "#{Rails.root}/lib/freedom_patches/rails_rack_logger_from_rails_7_2.rb",
].freeze
RUN_WITHOUT_PREPARE.each { |path| require(path) }

Rails.application.reloader.to_prepare do
  Dir["#{Rails.root}/lib/freedom_patches/*.rb"].each do |f|
    next if RUN_WITHOUT_PREPARE.any? { |path| path == f }
    require(f)
  end
end
