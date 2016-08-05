# sass-rails expects an actual file to exists when calling `@import`. However,
# we don't actually create the files for our special imports but rather inject
# them dynamically.
module Discourse
  module Sprockets
    module Resolve
      def resolve(path, options = {})
        return [path, []] if DiscourseSassImporter.special_imports.has_key?(File.basename(path, '.scss'))
        super
      end
    end
  end
end

module Sprockets
  class Base
    prepend Discourse::Sprockets::Resolve
  end
end
