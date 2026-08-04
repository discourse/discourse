# frozen_string_literal: true

module TurboRspecExclusion
  module_function

  def path_for_exclude_match(file)
    path = file.sub(/\[(?:\d+:)*\d+\]\z/, "")
    path = path.sub(/:\d+(?::\d+)?\z/, "")

    expanded_path = File.expand_path(path)
    working_directory = "#{Dir.pwd}/"

    if expanded_path.start_with?(working_directory)
      expanded_path.delete_prefix(working_directory)
    else
      path.delete_prefix("./")
    end
  end

  def excluded_by_patterns?(file, patterns)
    path = path_for_exclude_match(file)
    patterns.any? do |pattern|
      File.fnmatch(pattern, path) || File.fnmatch(pattern, path, File::FNM_PATHNAME)
    end
  end
end
