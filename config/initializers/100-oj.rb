# frozen_string_literal: true

Oj::Rails.set_encoder()
Oj::Rails.set_decoder()
Oj::Rails.optimize()

# Not sure why it's not using this by default!
MultiJson.engine = :oj
