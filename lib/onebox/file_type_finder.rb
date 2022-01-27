# frozen_string_literal: true

module Onebox
  module FileTypeFinder
    # In general, most of file extension names would be recognized
    # by Highlights.js.  However, some need to be checked in other
    # ways, either because they just aren't included, because they
    # are extensionless, or because they contain dots (they are
    # multi-part).
    # IMPORTANT: to prevent false positive matching, start all
    # entries on this list with a "."
    #
    # For easy reference, keep these sorted in alphabetical order.
    @long_file_types = {
      ".bib" => "tex",
      ".html.hbs" => "handlebars",
      ".html.handlebars" => "handlebars",
      ".latex" => "tex",
      ".ru" => "rb",
      ".simplecov" => "rb", # Not official, but seems commonly found
      ".sty" => "tex"
    }

    # Some extensionless files for which we know the type
    # These should all be stored LOWERCASE, just for consistency.
    # The ones that I know of also include the ".lock" fake extension.
    #
    # For easy reference, keep these sorted in alphabetical order,
    # FIRST by their types and THEN by their names.
    @extensionless_files = {
      "cmake.in" => "cmake",

      "gruntfile" => "js",
      "gulpfile" => "js",

      "artisan" => "php",

      "berksfile" => "rb",
      "capfile" => "rb",
      "cheffile" => "rb",
      "cheffile.lock" => "rb",
      "gemfile" => "rb",
      "guardfile" => "rb",
      "rakefile" => "rb",
      "thorfile" => "rb",
      "vagrantfile" => "rb",

      "boxfile" => "yaml" # Not currently (2014-11) in Highlight.js
    }

    def self.from_file_name(file_name)
      lower_name = file_name.downcase
      # First check against the known lists of "special" files and extensions.
      return @extensionless_files[lower_name] if @extensionless_files.has_key?(lower_name)

      @long_file_types.each { |extension, type|
        return type if lower_name.end_with?(extension)
      }

      # Otherwise, just split on the last ".",
      # but add one so we don't return the "." itself.
      dot_spot = lower_name.rindex(".")
      return lower_name[(dot_spot + 1)..-1] if dot_spot

      # If we couldn't figure it out from the name,
      # let the highlighter figure it out from the content.
      ""
    end
  end
end
