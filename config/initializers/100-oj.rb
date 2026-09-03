# frozen_string_literal: true

# Keep this order. `set_encoder` must run before `mode: :compat`, else oj formats a `Time` with
# nanoseconds and ignores the Rails time precision.
Oj::Rails.set_encoder()
Oj::Rails.set_decoder()
Oj::Rails.optimize()
Oj.default_options = Oj.default_options.merge(mode: :compat)
