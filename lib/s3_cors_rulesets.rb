# frozen_string_literal: true

class S3CorsRulesets
  ASSETS = {
    allowed_headers: ["Authorization"],
    allowed_methods: ["GET", "HEAD"],
    allowed_origins: ["*"],
    max_age_seconds: 3000
  }.freeze

  BACKUP_DIRECT_UPLOAD = {
    allowed_headers: ["*"],
    allowed_methods: ["PUT"],
    allowed_origins: [Discourse.base_url_no_prefix],
    max_age_seconds: 3000
  }.freeze
end
