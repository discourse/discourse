# frozen_string_literal: true

class ProblemCheck::UnreachableThemes < ProblemCheck
  self.priority = "low"

  def call
    return no_problem if unreachable_themes.empty?

    problem
  end

  private

  def translation_data
    { themes_list: }
  end

  def unreachable_themes
    @unreachable_themes ||= RemoteTheme.unreachable_themes
  end

  def themes_list
    <<~HTML.squish
      <ul>#{
      unreachable_themes
        .map do |name, id|
          "<li><a href=\"/admin/customize/themes/#{id}\">#{CGI.escapeHTML(name)}</a></li>"
        end
        .join("\n")
    }</ul>
    HTML
  end
end
