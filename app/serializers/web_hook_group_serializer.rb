# frozen_string_literal: true

class WebHookGroupSerializer < BasicGroupSerializer
  %i[is_group_user is_group_owner].each { |attr| define_method("include_#{attr}?") { false } }
end
