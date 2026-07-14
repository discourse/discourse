# frozen_string_literal: true

Oj::Rails.set_encoder()
Oj::Rails.set_decoder()
Oj::Rails.optimize()
Oj.default_options = Oj.default_options.merge(mode: :compat)
