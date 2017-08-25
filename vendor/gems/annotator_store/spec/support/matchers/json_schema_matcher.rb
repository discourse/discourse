RSpec::Matchers.define :match_json_schema do |schema_key|
  match do |response|
    schema_directory = "#{Dir.pwd}/spec/support/schemas"
    schema_path = "#{schema_directory}/#{schema_key}.json"
    JSON::Validator.validate!(schema_path, response.body, strict: true)
  end
end
