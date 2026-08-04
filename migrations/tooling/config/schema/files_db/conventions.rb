# frozen_string_literal: true

# Unlike the IntermediateDB, FilesDB keeps the real Discourse ids and types:
# `id` stays `id` (a real staging `Upload#id`), and `*_id` columns keep their
# introspected integer type. So there's no `id -> original_id` rename and no
# `*upload*_id -> text` rule here.
Migrations::Tooling::Schema.conventions do
  column :created_at do
    required false
  end

  # Globally ignored columns
  ignore_columns :updated_at
end
