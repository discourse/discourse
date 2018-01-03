module Searchable
  extend ActiveSupport::Concern

  included do
    has_one "#{self.name.underscore}_search_data".to_sym, dependent: :destroy
  end
end
