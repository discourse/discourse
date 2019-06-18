# frozen_string_literal: true

module HasSearchData
  extend ActiveSupport::Concern

  included do
    _associated_record_name = self.name.sub('SearchData', '').underscore
    self.primary_key = "#{_associated_record_name}_id"
    belongs_to _associated_record_name.to_sym
    validates_presence_of :search_data
  end
end
