# frozen_string_literal: true

require "seed_data/categories"

SeedData::Categories.with_default_locale.create if !Rails.env.test?
