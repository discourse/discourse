# This class is used to generate diffs, it will be consumed by the UI on
# on the client the displays diffs.
#
# Ruby has the diff/lcs engine that can do some of the work, the devil
#  is in the details

class DiffEngine

  # generate an html friendly diff similar to the way Stack Exchange generate
  #  html diffs
  #
  #  returns: html containing decorations indicating the changes
  def self.html_diff(html_before, html_after)
  end

  # same as html diff, except that it operates on markdown
  #
  # returns html containing decorated areas where diff happened
  def self.markdown_diff(markdown_before, markdown_after)
  end
end
