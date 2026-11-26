# frozen_string_literal: true

class Topic
  module KeywordSearch
    STATEMENT_TIMEOUT_MS = 10_000

    def self.valid_term?(term)
      term.present? && term.to_s.length >= SiteSetting.min_search_term_length
    end

    def with_keyword_search_timeout
      results = nil

      ActiveRecord::Base.transaction(requires_new: true) do
        DB.exec(<<~SQL, timeout: STATEMENT_TIMEOUT_MS)
          SELECT set_config('statement_timeout', LEAST(NULLIF(setting::int, 0), :timeout)::text, true)
          FROM pg_settings
          WHERE name = 'statement_timeout'
        SQL

        results = yield
        raise ActiveRecord::Rollback
      rescue ActiveRecord::QueryCanceled, PG::QueryCanceled
        raise Discourse::InvalidParameters.new(I18n.t("search.keyword_search_timeout"))
      end

      results
    end
  end
end
