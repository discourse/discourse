# frozen_string_literal: true

module MarkdownEndpoint
  class DirectoryRenderer
    def self.navigation
      links = [
        "[#{I18n.t("markdown_endpoints.latest")}](#{Discourse.base_url}/latest.md)",
        "[#{I18n.t("markdown_endpoints.categories")}](#{Discourse.base_url}/categories.md)",
      ]
      if SiteSetting.tagging_enabled
        links << "[#{I18n.t("markdown_endpoints.tags")}](#{Discourse.base_url}/tags.md)"
      end
      links.join(" · ")
    end

    def categories(category_list, params = {})
      records =
        category_list.categories.flat_map { |category| category_entries(category) }.uniq(&:id)
      parents = records.index_by(&:id)
      lines = header("categories", records)
      records.each do |category|
        append_entry(lines, category.name, category.url, category.description)
        if parent = parents[category.parent_category_id]
          lines.concat(
            ["", I18n.t("markdown_endpoints.parent", parent: link(parent.name, parent.url))],
          )
        end
      end

      page = [params["page"].to_i, 1].max
      lines.concat(["", page_link("previous_page", params, page - 1)]) if page > 1
      if category_list.next_page
        lines.concat(["", page_link("next_page", params, category_list.next_page)])
      end
      "#{lines.join("\n")}\n"
    end

    def tags(tags, extras)
      records =
        (tags + extras.values.flatten.flat_map { |group| group[:tags] }).uniq { |tag| tag[:id] }
      lines = header("tags", records)
      records.each do |tag|
        append_entry(
          lines,
          tag[:name],
          "#{Discourse.base_path}/tag/#{tag[:slug]}/#{tag[:id]}",
          tag[:description],
        )
      end
      "#{lines.join("\n")}\n"
    end

    private

    def category_entries(category)
      [category, *Array(category.subcategory_list).flat_map { |child| category_entries(child) }]
    end

    def header(kind, records)
      lines = ["# #{I18n.t("markdown_endpoints.#{kind}")}", "", self.class.navigation]
      lines.concat(["", I18n.t("markdown_endpoints.empty")]) if records.empty?
      lines
    end

    def append_entry(lines, name, url, description)
      lines.concat(["", "## #{link(name, url)}"])
      excerpt = Nokogiri::HTML5.fragment(description.to_s).text.squish.truncate(200)
      lines.concat(["", escape_text(excerpt)]) if excerpt.present?
    end

    def link(name, url)
      "[#{escape_text(name)}](#{Discourse.base_url_no_prefix}#{url}.md)"
    end

    def page_link(label, params, page)
      query = params.merge("page" => page).to_query
      "[#{I18n.t("markdown_endpoints.#{label}")}](#{Discourse.base_url}/categories.md?#{query})"
    end

    def escape_text(text)
      text.to_s.gsub(/[\\`*_\[\]<>]/) { |character| "\\#{character}" }
    end
  end
end
