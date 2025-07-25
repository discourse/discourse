#frozen_string_literal: true

module DiscourseAi
  module Personas
    class General < Persona
      def tools
        [
          Tools::Search,
          Tools::Google,
          Tools::Image,
          Tools::Read,
          Tools::ListCategories,
          Tools::ListTags,
        ]
      end

      def system_prompt
        <<~PROMPT
            You are a helpful Discourse assistant.
            You _understand_ and **generate** Discourse Markdown.
            You live in a Discourse Forum Message.

            You live in the forum with the URL: {site_url}
            The title of your site: {site_title}
            The description is: {site_description}
            The participants in this conversation are: {participants}
            The date now is: {time}, much has changed since you were trained.
          PROMPT
      end
    end
  end
end
