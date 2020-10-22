# frozen_string_literal: true
require 'json'

# This script is used for development to help document rswag api responses.  It
# takes a json response string as an input and converts it to ruby in the format
# that rswag wants so that you can copy+paste it into the appropriate spec rather
# than typing it by hand.
#
# example:
#
# ruby script/json_to_rswag.rb '{"success":true,"active":true,"message":"Your account is activated and ready to use.","user_id":18}'
#
# will output:
#
# schema type: :object, properties: {
#   success: { type: :boolean },
#   active: { type: :boolean },
#   message: { type: :string },
#   user_id: { type: :integer },
# }

class JsonToRswag

  def initialize
    @output = Array.new
    @output.push("schema type: :object, properties: {")
  end

  def get_type(k, v)
    type = ""
    type = "integer" if v.is_a? Integer
    type = "number" if v.is_a? Float
    type = "object" if v.is_a? Hash
    type = "array" if v.is_a? Array
    type = "boolean" if v == true || v == false
    type = "null" if v == nil
    type = "string" if v.is_a? String
    if type == ""
      puts "Cannot determine type for:"
      puts v
      exit 1
    end
    type
  end

  def run(h, indent)
    h.each do |k, v|
      type = get_type(k, v)

      if type == "object"
        @output << "#{' ' * indent}#{k}: {"
        @output << "#{' ' * (indent + 2)}type: :object,"
        @output << "#{' ' * (indent + 2)}properties: {"
        run(v, indent + 4)
        @output << "#{' ' * indent}},"
      end

      if type == "array"
        @output << "#{' ' * indent}#{k}: {"
        @output << "#{' ' * (indent + 2)}type: :array,"
        @output << "#{' ' * (indent + 2)}items: {"
        a = v.first
        if a.is_a? Hash
          @output << "#{' ' * (indent + 4)}type: :object,"
          @output << "#{' ' * (indent + 4)}properties: {"
          run(a , indent + 6)
          @output << "#{' ' * (indent + 2)}},"
        else
          @output << "#{' ' * (indent + 2)}},"
        end
        @output << "#{' ' * indent}},"
      end

      if type == "null"
        @output << "#{' ' * indent}#{k}: { type: :string, nullable: true },"
      elsif type != "object" && type != "array"
        @output << "#{' ' * indent}#{k}: { type: :#{type} },"
      end
    end

    @output << "#{' ' * (indent - 2)}}"
  end

  def print
    puts @output
  end

end

input = ARGV[0]

if input == nil || input == ""
  puts "Please pass in a json string."
  exit 1
end

json = JSON.parse(input)

json_to_rswag = JsonToRswag.new
json_to_rswag.run(json, 2)
json_to_rswag.print
