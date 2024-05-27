# frozen_string_literal: true

class ProblemCheck::UnreachableThemes < ProblemCheck
  self.priority = "low"

  def call
    return no_problem if unreachable_themes.empty?

    problem
  end

  private

  def unreachable_themes
    @unreachable_themes ||= RemoteTheme.unreachable_themes
  end

  def message
    "#{I18n.t("dashboard.problem.unreachable_themes")}<ul>#{themes_list}</ul>"
  end

  def themes_list
    unreachable_themes
      .map do |name, id|
        "<li><a href=\"/admin/customize/themes/#{id}\">#{CGI.escapeHTML(name)}</a></li>"
      end
      .join("\n")
  end
end
