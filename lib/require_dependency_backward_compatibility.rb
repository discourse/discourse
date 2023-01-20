# frozen_string_literal: true

# Patch `require_dependency` to maintain backward compatibility with some
# plugins. Calls to `require_dependency` are deprecated and we should remove
# them whenever possible.
#
# Here we do nothing if `jobs/base` is required since all our jobs are
# autoloaded through Zeitwerk. Requiring explicitly `jobs/base` actually breaks
# the app with the “new” autoloader.
# `lib` should not appear in a path that is required but we had probably a bug
# at some point regarding this matter so we need to maintain compatibility with
# some plugins that rely on this.
module RequireDependencyBackwardCompatibility
  def require_dependency(filename)
    name = filename.to_s
    return if name == "jobs/base"
    return super(name.sub(%r{\Alib/}, "")) if name.start_with?("lib/")
    super
  end

  Object.prepend(self)
end
