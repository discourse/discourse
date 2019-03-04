if !Rails.env.test?
  SeedData::Categories.with_default_locale.create
end
