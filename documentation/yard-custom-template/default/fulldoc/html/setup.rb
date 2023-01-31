# frozen_string_literal: true

# Order was not deterministic for identic method names defined with @!method
# so we sort the list on path instead
def generate_method_list
  @items =
    prune_method_listing(Registry.all(:method), false)
      .reject { |m| m.name.to_s =~ /=$/ && m.is_attribute? }
      .sort_by { |m| m.path }
  @list_title = "Method List"
  @list_type = "method"
  generate_list_contents
end
