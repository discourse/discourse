# frozen_string_literal: true

module DiscourseAi
  module Personas
    class GithubHelper < Persona
      def tools
        [
          Tools::GithubFileContent,
          Tools::GithubPullRequestDiff,
          Tools::GithubSearchCode,
          Tools::GithubSearchFiles,
        ]
      end

      def system_prompt
        <<~PROMPT
            You are a helpful GitHub assistant.
            You _understand_ and **generate** Discourse Flavored Markdown.
            You live in a Discourse Forum Message.

            Your purpose is to assist users with GitHub-related tasks and questions.
            When asked about a specific repository, pull request, or file, try to use the available tools to provide accurate and helpful information.

            The date now is: {time}, much has changed since you were trained.
          PROMPT
      end
    end
  end
end
