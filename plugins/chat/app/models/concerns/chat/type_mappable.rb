# frozen_string_literal: true

module Chat
  module TypeMappable
    extend ActiveSupport::Concern

    class_methods do
      def sti_class_mapping = {}
      def polymorphic_class_mapping = {}

      # the model used when loading type column
      def sti_class_for(name)
        sti_class_mapping[name] || super
      end

      # the type column value
      def sti_name
        sti_class_mapping.invert[self] || super
      end

      # the model used when loading *_type column (e.g. 'chatable_type')
      def polymorphic_class_for(name)
        polymorphic_class_mapping[name] || super
      end

      # the *_type column value (e.g. 'chatable_type')
      def polymorphic_name
        polymorphic_class_mapping.invert[self] || super
      end
    end
  end
end
