module Concern
  module HasCustomFields
    extend ActiveSupport::Concern

    included do
      has_many :_custom_fields, dependent: :destroy, :class_name => "#{name}CustomField"
      after_save :save_custom_fields
    end

    def custom_fields
      @custom_fields ||= begin
        @custom_fields_orig = Hash[*_custom_fields.pluck(:name,:value).flatten]
        @custom_fields_orig.dup
      end
    end

    protected

    def save_custom_fields
      if @custom_fields && @custom_fields_orig != @custom_fields
        dup = @custom_fields.dup

        _custom_fields.each do |f|
          if dup[f.name] != f.value
            f.destroy
          else
            dup.remove[f.name]
          end
        end

        dup.each do |k,v|
          _custom_fields.create(name: k, value: v)
        end

        @custom_fields_orig = @custom_fields
      end
    end
  end
end