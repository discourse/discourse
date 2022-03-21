# frozen_string_literal: true

# Patch `require_dependency` to maintain backward compatibility with some
# plugins. Calls to `require_dependency` are deprecated and we should remove
# them whenever possible.
module RequireDependencyBackwardCompatibility
  def require_dependency(filename)
    name = filename.to_s
    return if name == 'jobs/base'
    return super(name.sub(/^lib\//, '')) if name.start_with?('lib/')
    super
  end

  Object.prepend(self)
end
