# frozen_string_literal: true

class DiscourseInflector < Zeitwerk::Inflector
  def camelize(basename, abspath)
    return basename.camelize if abspath.ends_with?("onceoff.rb")
    return 'Jobs' if abspath.ends_with?("jobs/base.rb")
    super
  end
end
