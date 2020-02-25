# frozen_string_literal: true

module Onebox
  class DiscourseOneboxSanitizeConfig
    module Config
      DISCOURSE_ONEBOX ||=
        Sanitize::Config.freeze_config(
          Sanitize::Config.merge(Sanitize::Config::ONEBOX,
                                 attributes: Sanitize::Config.merge(Sanitize::Config::ONEBOX[:attributes],
                                                                    'aside' => [:data])))
    end
  end
end
