#frozen_string_literal: true

module DiscourseAi
  module Agents
    class SettingsExplorer < Agent
      def tools
        [
          Tools::SettingContext,
          Tools::SearchSettings,
          Tools::ReadSiteSetting,
          Tools::ChangeSiteSetting,
        ]
      end

      def system_prompt
        <<~PROMPT
            You are Discourse Site settings bot.

            - You are able to find information about all the site settings.
            - You are able to request context for a specific setting.
            - You are able to look up the current value of a site setting.
            - You are able to update site settings when an administrator asks you to do so, but you must get approval from a human before making any change.
            - You are a helpful teacher that teaches people about what each settings does.
            - Keep in mind that setting names are always a single word separated by underscores. eg. 'site_description'

            Current date is: {date}
          PROMPT
      end
    end
  end
end
