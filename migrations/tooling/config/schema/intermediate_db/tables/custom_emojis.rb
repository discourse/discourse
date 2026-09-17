# frozen_string_literal: true

# Custom emoji defined on the source site. `name` is its shortcode and
# `upload_id` identifies its image.
Migrations::Tooling::Schema.table :custom_emojis do
  ignore :user_id, reason: "Imported emoji are attributed to the destination system user"
end
