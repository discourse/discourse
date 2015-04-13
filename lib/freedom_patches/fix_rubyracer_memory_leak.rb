## TODO: DELETE ME WHEN https://github.com/cowboyd/therubyracer/pull/336
# is upstreamed and released
#
module V8
  module Weak
      class WeakValueMap
        def initialize
          @values = {}
        end

        def [](key)
          if ref = @values[key]
            ref.object
          end
        end

        def []=(key, value)
          ref = V8::Weak::Ref.new(value)
          ObjectSpace.define_finalizer(value, self.class.ensure_cleanup(@values, key, ref))

          @values[key] = ref
        end

        private

        def self.ensure_cleanup(values,key,ref)
          proc {
            values.delete(key) if values[key] == ref
          }
        end
      end
  end
end
