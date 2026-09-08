# frozen_string_literal: true

module Boards
  class OneboxHandler
    class << self
      def handle(url, route, opts = {})
        opts ||= {}

        if route[:card_id].present?
          build_card_onebox(url, route[:card_id], route[:id], opts)
        else
          build_board_onebox(url, route[:id])
        end
      end

      def build_card_onebox(url, card_id, board_id, opts)
        card = Boards::Card.find_by(id: card_id, board_id: board_id)
        return "" if !card || !card.board.can_be_oneboxed?

        if card.topic?
          if card.topic.blank? ||
               Oneboxer.local_topic(card.topic.url, { id: card.topic_id }, opts).blank?
            return ""
          end
        end

        tag_html = ""
        if card.tags.any?
          tag_hashtags = card.tags.map { |tag| "##{tag.name}" }.join("\n")
          tag_html =
            Nokogiri::HTML5.fragment(PrettyText.cook(tag_hashtags)).css("a").map(&:to_s).join("\n")
        end

        updated_at = card.updated_at || card.created_at

        args = {
          board_url: card.board.url,
          board_name: card.board.unicode_name,
          card_url: url,
          card_name: card.unicode_resolved_title,
          card_tags: tag_html,
          card_column_title: card.column.unicode_title,
          card_column_icon: card.column.icon,
          creator_username: card.created_by.username,
          creator_avatar_url: card.created_by.small_avatar_url,
          updater_username: card.updated_by.username,
          updater_avatar_url: card.updated_by.small_avatar_url,
          notes:
            PrettyText.excerpt(
              PrettyText.cook(card.notes),
              SiteSetting.post_onebox_maxlength,
              keep_svg: true,
            ),
          created_by: I18n.t("boards.onebox.created_by", username: card.created_by.display_name),
          updated_by: I18n.t("boards.onebox.updated_by", username: card.updated_by.display_name),
          updated_at_ms: (updated_at.to_f * 1000).to_i,
          updated_at_title: I18n.l(updated_at, format: :long),
          updated_at_tiny: AgeWords.age_words((Time.now - updated_at).to_i),
          onebox_type: I18n.t("boards.onebox.card"),
          tags_preview: card.tags.any?,
          has_notes: card.notes.present?,
        }

        Mustache.render(Boards.card_onebox_template, args)
      end

      def build_board_onebox(url, board_id)
        board = Boards::Board.find_by(id: board_id)
        return "" if !board || !board.can_be_oneboxed?

        tag_html = ""
        if board.tags.any?
          tag_hashtags = board.tags.map { |tag| "##{tag.name}" }.join("\n")
          tag_html =
            Nokogiri::HTML5.fragment(PrettyText.cook(tag_hashtags)).css("a").map(&:to_s).join("\n")
        end

        category_html = ""
        if board.categories.any?
          category_hashtags = board.categories.map { |category| "##{category.name}" }.join("\n")
          category_html =
            Nokogiri::HTML5
              .fragment(PrettyText.cook(category_hashtags))
              .css("a")
              .map(&:to_s)
              .join("\n")
        end

        args = {
          board_url: url,
          board_name: board.unicode_name,
          board_tags: tag_html,
          board_categories: category_html,
          board_columns:
            board
              .columns
              .select(:title, :icon)
              .map { |column| { name: column.unicode_title, icon: column.icon } },
          creator_username: board.created_by.username,
          creator_avatar_url: board.created_by.small_avatar_url,
          created_by: I18n.t("boards.onebox.created_by", username: board.created_by.display_name),
          column_count: I18n.t("boards.onebox.column_count", count: board.columns.count),
          onebox_type: I18n.t("boards.onebox.board"),
          tags_preview: board.tags.any?,
          categories_preview: board.categories.any?,
          has_constraints: board.tags.any? || board.categories.any?,
          columns_preview: board.columns.any?,
        }

        Mustache.render(Boards.board_onebox_template, args)
      end
    end

    private
  end
end
