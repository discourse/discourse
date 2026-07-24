# frozen_string_literal: true

require "seed_data/categories"

if Rails.env.test?
  # Tests need the Uncategorized category, but none of the others.
  SeedData::Categories.with_default_locale.create(site_setting_names: ["uncategorized_category_id"])
else
  SeedData::Categories.with_default_locale.create
end
