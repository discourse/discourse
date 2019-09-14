# frozen_string_literal: true

module Jobs
  class MigrateCensoredWords < ::Jobs::Onceoff
    def execute_onceoff(args)
      row = DB.query_single("SELECT value FROM site_settings WHERE name = 'censored_words'")
      if row.count > 0
        row.first.split('|').each do |word|
          WatchedWord.create(word: word, action: WatchedWord.actions[:censor])
        end
      end
    end
  end
end
