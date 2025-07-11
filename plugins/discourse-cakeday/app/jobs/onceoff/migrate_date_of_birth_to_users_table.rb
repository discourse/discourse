# frozen_string_literal: true

module Jobs
  class MigrateDateOfBirthToUsersTable < ::Jobs::Onceoff
    def execute_onceoff(args)
      UserCustomField
        .where(name: "date_of_birth")
        .find_each do |custom_field|
          value = custom_field.value

          if value.present?
            begin
              date = Date.parse(value)
            rescue ArgumentError
              # Just drop migration of custom field
            end

            custom_field.user.update!(date_of_birth: date)
          else
            custom_field.destroy!
          end
        end
    end
  end
end
