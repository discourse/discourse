# frozen_string_literal: true

# sorting was not idempotent
def generate_method_list
  super.sort(:name)
end
