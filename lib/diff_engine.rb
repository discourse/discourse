require 'diffy'
# This class is used to generate diffs, it will be consumed by the UI on
# on the client the displays diffs.
#
# There are potential performance issues associated with diffing large amounts of completely
# different text, see answer here for optimization if needed
# http://meta.stackoverflow.com/questions/127497/suggested-edit-diff-shows-different-results-depending-upon-mode

class DiffEngine

  # generate an html friendly diff similar to the way Stack Exchange generates
  # html diffs
  #
  #  returns: html containing decorations indicating the changes
  def self.html_diff(html_before, html_after)
    Diffy::Diff.new(html_before, html_after, {allow_empty_diff: false}).to_s(:html)
  end

  # same as html diff, except that it operates on markdown
  #
  # returns html containing decorated areas where diff happened
  def self.markdown_diff(markdown_before, markdown_after)
    Diffy::Diff.new(markdown_before, markdown_after).to_s(:html)
  end
end
