# frozen_string_literal: true

RSpec::Matchers.define :match_response_schema do |schema|
  match do |object|
    schema_directory = "#{Dir.pwd}/plugins/chat/spec/support/api/schemas"
    schema_path = "#{schema_directory}/#{schema}.json"

    begin
      JSON::Validator.validate!(schema_path, object, strict: true)
    rescue JSON::Schema::ValidationError => e
      puts "-- Printing response body after validation error\n"
      pp object
      raise e
    end
  end
end
