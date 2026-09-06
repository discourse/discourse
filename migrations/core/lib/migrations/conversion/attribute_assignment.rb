# frozen_string_literal: true

module Migrations
  module Conversion
    # Assigns constructor args to the attributes that declare a matching
    # public setter; args without one are silently ignored. This is how
    # `Base#create_step` routes args like `source_db` to whichever step or
    # role object declares an accessor for them.
    module AttributeAssignment
      private

      def assign_attributes(args)
        args.each do |arg, value|
          setter = :"#{arg}="
          public_send(setter, value) if respond_to?(setter)
        end
      end
    end
  end
end
