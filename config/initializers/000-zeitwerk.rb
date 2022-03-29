# frozen_string_literal: true

# This custom inflector is needed because of our jobs directory structure.
# Ideally, we should not prefix our jobs with a `Jobs` namespace but instead
# have a `Job` suffix to follow the Rails conventions on naming.
class DiscourseInflector < Zeitwerk::Inflector
  def camelize(basename, abspath)
    return basename.camelize if abspath.ends_with?("onceoff.rb")
    return 'Jobs' if abspath.ends_with?("jobs/base.rb")
    super
  end
end

Rails.autoloaders.each do |autoloader|
  autoloader.inflector = DiscourseInflector.new

  # We have filenames that do not follow Zeitwerk's camelization convention. Maintain an inflections for these files
  # for now until we decide to fix them one day.
  autoloader.inflector.inflect(
    'onceoff' => 'Jobs',
    'regular' => 'Jobs',
    'scheduled' => 'Jobs',
  )
end
Rails.autoloaders.main.ignore("lib/tasks",
                              "lib/generators")
