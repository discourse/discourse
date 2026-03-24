# frozen_string_literal: true

task "javascript:update_constants" => :environment do
  write_template(
    "../plugins/discourse-data-explorer/assets/javascripts/discourse/lib/constants.js",
    "update_constants",
    <<~JS,
      export const QUERY_RESULT_MAX_LIMIT = #{DiscourseDataExplorer::QUERY_RESULT_MAX_LIMIT};
    JS
  )
end
