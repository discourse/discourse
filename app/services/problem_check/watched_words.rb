# frozen_string_literal: true

class ProblemCheck::WatchedWords < ProblemCheck
  self.priority = "low"

  def call
    return no_problem if invalid_regexp_actions.empty?

    problem
  end

  private

  def translation_data
    { action: invalid_regexp_actions.map { |w| "'#{w}'" }.join(", ") }
  end

  def invalid_regexp_actions
    @invalid_regexp_actions ||=
      WatchedWord.actions.keys.filter_map do |action|
        WordWatcher.compiled_regexps_for_action(action, raise_errors: true)
        nil
      rescue RegexpError
        I18n.t("admin_js.admin.watched_words.actions.#{action}")
      end
  end
end
