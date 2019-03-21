RSpec::Matchers.define :rate_limit do |attribute|
  match { |model| model.class.include? RateLimiter::OnCreateRecord }
end
