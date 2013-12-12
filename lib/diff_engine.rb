# This class is used to generate diffs, it will be consumed by the UI on the client that displays diffs.
#
# There are potential performance issues associated with diffing large amounts of completely
# different text, see answer here for optimization if needed
# http://meta.stackoverflow.com/questions/127497/suggested-edit-diff-shows-different-results-depending-upon-mode

class DiffEngine

  # Generate an html friendly diff
  #
  #  returns: html containing decorations indicating the changes
  def self.html_diff(html_before, html_after)
    # tokenize
    # remove leading/trailing common
    # SES
    # format diff
  end

  # Same as html diff, except that it operates on markdown
  #
  # returns html containing decorated areas where diff happened
  def self.markdown_diff(markdown_before, markdown_after)

  end
end
