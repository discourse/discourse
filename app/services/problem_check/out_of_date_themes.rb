# frozen_string_literal: true

class ProblemCheck::OutOfDateThemes < ProblemCheck
  self.priority = "low"

  def call
    return no_problem if out_of_date_themes.empty?

    problem
  end

  private

  def translation_data
    { themes_list: }
  end

  def out_of_date_themes
    @out_of_date_themes ||= RemoteTheme.out_of_date_themes
  end

  def themes_list
    <<~HTML.squish
      <ul>#{
      out_of_date_themes
        .map do |name, id|
          "<li><a href=\"#{Discourse.base_path}/admin/customize/themes/#{id}\">#{CGI.escapeHTML(name)}</a></li>"
        end
        .join("\n")
    }</ul>
    HTML
  end
end
