# frozen_string_literal: true

module SpecSchemas

  class TagGroupCreateRequest
    def schemer
      schema = {
        'type' => 'object',
        'properties' => {
          'name' => {
            'type' => 'string',
            'required' => true
          }
        }
      }
    end
  end

  class TagGroupResponse
    def schemer
      schema = {
        'type' => 'object',
        'properties' => {
          'tag_group' => {
            'type' => 'object',
            'properties' => {
              'id' => {
                'type' => 'integer',
                'required' => true
              },
              'name' => {
                'type' => 'string',
                'required' => true
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
            }
          }
        }
      }
    end
  end

end
