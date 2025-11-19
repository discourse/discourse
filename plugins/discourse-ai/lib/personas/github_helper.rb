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

          When answering GitHub questions, use available tools to search repositories, read files, and fetch PR/issue details.

          ALWAYS link to relevant GitHub resources:
          - Files: [file.rb](https://github.com/owner/repo/blob/branch/file.rb#L10-L25)
          - PRs/Issues: [#123](https://github.com/owner/repo/pull/123)

          The date now is: {date}, much has changed since you were trained.
        PROMPT
      end
    end
  end
end
