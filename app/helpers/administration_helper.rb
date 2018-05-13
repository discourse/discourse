require 'current_user'

# damingo (Github ID), 2017-08-24, #annotator
#
module AdministrationHelper
  include CurrentUser


  # http://stackoverflow.com/questions/7674754/how-to-arrange-entries-from-ancestry-tree-in-dropdown-list-in-rails-3
  def nested_dropdown(items)
    result = []
    items.map do |item, sub_items|
      result << [('- ' * item.depth) + item.name_with_count, item.id]
      result += nested_dropdown(sub_items) unless sub_items.blank?
    end
    result
  end


end
