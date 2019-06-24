# frozen_string_literal: true

Oj.optimize_rails

# Not sure why it's not using this by default!
MultiJson.engine = :oj
