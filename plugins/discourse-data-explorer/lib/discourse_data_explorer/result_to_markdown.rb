# frozen_string_literal: true

module DiscourseDataExplorer
  class ResultToMarkdown
    extend HasSanitizableFields

    LABEL_COLUMNS = %w[username title name]
    SANITIZABLE_REGEX = /[<>&%]/

    def self.convert(pg_result, render_url_columns: false)
      relations, colrender = DataExplorer.add_extra_data(pg_result)
      relations.transform_values! { |related| related.object.index_by(&:id) }

      column_renders =
        pg_result.fields.each_index.map do |col_index|
          col_render = colrender[col_index]
          [col_render, relations[col_render&.to_sym]]
        end

      result_data =
        pg_result.each_row.map do |row|
          cells =
            row.each_with_index.map do |col, col_index|
              col_render, table = column_renders[col_index]
              related_row = table[col.to_i] if table && col

              if related_row
                label = LABEL_COLUMNS.filter_map { |c| related_row.try(c) }.first
                label ? "#{label} (#{col})" : col
              elsif col_render == "url" && render_url_columns && col.present?
                url, text = guess_url(col)
                "[#{text}](#{url})"
              else
                col
              end
            end

          cells.map { |c| "| #{escape_cell(c)} " }.join + "|\n"
        end

      table_headers = pg_result.fields.map { |c| " #{c.delete_suffix("_id")} |" }.join
      table_body = pg_result.fields.size.times.map { " :----- |" }.join

      "|#{table_headers}\n|#{table_body}\n#{result_data.join}"
    end

    def self.escape_cell(value)
      value = value.to_s
      value = sanitize_field(value) if value.match?(SANITIZABLE_REGEX)

      value.gsub("|", "\\|").gsub(/\R+/, " ")
    end

    def self.guess_url(column_value)
      column_value = column_value.to_s
      text, url = column_value.split(/,(.+)/)

      [url || column_value, text || column_value]
    end
  end
end
