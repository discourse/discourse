module Searchable
  extend ActiveSupport::Concern

  PRIORITIES = Enum.new(normal: 0, ignore: 1)

  included do
    has_one "#{self.name.underscore}_search_data".to_sym, dependent: :destroy
  end
end
