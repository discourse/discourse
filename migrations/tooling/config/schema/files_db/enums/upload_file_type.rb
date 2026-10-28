# frozen_string_literal: true

Migrations::Tooling::Schema.enum :upload_file_type do
  value :image, 0
  value :audio, 1
  value :video, 2
  value :attachment, 3
end
