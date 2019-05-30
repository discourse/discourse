# frozen_string_literal: true

require 'seed_data/categories'

if !Rails.env.test?
  SeedData::Categories.with_default_locale.create
end
