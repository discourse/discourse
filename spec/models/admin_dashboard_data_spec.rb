# frozen_string_literal: true

RSpec.describe AdminDashboardData do
  after { Discourse.redis.flushdb }

  describe "stats cache" do
    include_examples "stats cacheable"
  end
end
