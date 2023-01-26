# frozen_string_literal: true

# order was not idempotent
def generate_method_list
  super
  @items.sort(:to_s)
end
