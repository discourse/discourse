# frozen_string_literal: true

module SpecSchemas

  class TagGroupCreateRequest
    def schemer
      schema = {
        'type' => 'object',
        'additionalProperties' => false,
        'properties' => {
          'name' => {
            'type' => 'string',
          }
        },
        'required' => ['name']
      }
    end
  end

  class TagGroupResponse
    def schemer
      schema = {
        'type' => 'object',
        'additionalProperties' => false,
        'properties' => {
          'tag_group' => {
            'type' => 'object',
            'properties' => {
              'id' => {
                'type' => 'integer',
              },
              'name' => {
                'type' => 'string',
              },
              'tag_names' => {
                'type' => 'array',
                'items' => {
                  'type' => 'string'
                }
              },
              'parent_tag_name' => {
                'type' => 'array',
                'items' => {
                  'type' => 'string'
                }
              },
              'one_per_topic' => {
                'type' => 'boolean',
              },
              'permissions' => {
                'type' => 'object',
                'properties' => {
                  'everyone' => {
                    'type' => 'integer',
                    'example' => 1
                  }
                }
              }
            },
            'required' => [
              'id',
              'name',
              'tag_names',
              'parent_tag_name',
              'one_per_topic',
              'permissions'
            ]
          }
        },
        'required' => [
          'tag_group'
        ]
      }
    end
  end

end
