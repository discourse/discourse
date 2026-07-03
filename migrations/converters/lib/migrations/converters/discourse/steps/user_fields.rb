# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      class UserFields < Conversion::ProgressStep
        source { reads_table "user_fields" }

        processor do
          def process(item)
            IntermediateDB::UserField.create(
              original_id: item[:id],
              created_at: item[:created_at],
              description: item[:description],
              editable: item[:editable],
              external_name: item[:external_name],
              external_type: item[:external_type],
              field_type_enum: item[:field_type_enum],
              name: item[:name],
              position: item[:position],
              requirement: item[:requirement],
              searchable: item[:searchable],
              show_on_profile: item[:show_on_profile],
              show_on_signup: item[:show_on_signup],
              show_on_user_card: item[:show_on_user_card],
            )
          end
        end
      end
    end
  end
end
