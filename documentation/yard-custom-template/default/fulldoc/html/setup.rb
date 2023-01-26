# frozen_string_literal: true

# order was not idempotent
def generate_method_list
  super
  @items.sort { |a, b| a.to_s <=> b.to_s }
end
