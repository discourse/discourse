# frozen_string_literal: true

module SpecSchemas

  class TagGroupCreateRequest
    include JSON::SchemaBuilder

    def schema
      object do
        string :name, required: true
      end
    end
  end

  class TagGroupResponse
    include JSON::SchemaBuilder

    def schema
      object do
        object :tag_group do
          integer :id, required: true
          string :name, required: true
          array :tag_names do
            items type: :string
          end
          array :parent_tag_name do
            items type: :string
          end
          boolean :one_per_topic
          object :permissions do
            integer :everyone
          end
        end
      end
    end
  end

end
