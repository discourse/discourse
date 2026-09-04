# frozen_string_literal: true

# Extracts `Upload` ids from a `block_layout` ThemeField value so the field
# can claim ownership of those uploads via `UploadReference`.
#
# The cleanup is shape-driven, not schema-driven: any nested Hash inside the
# layout JSON that has `"source" => "upload"` and an integer `"upload_id"` is
# collected. This is the same shape every `type: "image"` arg persists (see
# `validateImageVariant` in lib/blocks/-internals/validation/args.js), so any
# future block that exposes an image arg participates automatically without a
# corresponding server change.
module BlockLayoutUploads
  # Walks the parsed JSON of a `block_layout` field and returns the unique,
  # positive-integer `upload_id`s of every embedded upload. Returns `[]` for
  # malformed or empty input — the server-side bake step rejects malformed
  # payloads before persistence, so this is purely defensive.
  #
  # @param value [String, nil] the ThemeField's `value` column (JSON string)
  # @return [Array<Integer>] unique upload ids found in the layout
  def self.extract(value)
    return [] if value.blank?

    parsed =
      begin
        JSON.parse(value)
      rescue JSON::ParserError
        nil
      end
    return [] if parsed.nil?

    ids = []
    collect(parsed, ids)
    ids.uniq
  end

  # Claims every upload embedded in a layout's JSON for the given target so the
  # hourly `Jobs::CleanUpUploads` doesn't garbage-collect them as orphans. This
  # is the single binding path shared by every table that stores layout JSON.
  #
  # `ensure_exist!` also prunes references this target previously held for
  # uploads no longer present, so removing or swapping an image in a layout
  # reconciles automatically. The ids are filtered against the current `Upload`
  # table to skip any client-supplied id that points to a non-existent (or
  # just-deleted) upload row.
  #
  # @param target [ActiveRecord::Base] the record that owns the layout JSON
  # @param value [String, nil] the layout JSON string
  # @return [void]
  def self.sync!(target:, value:)
    ids = extract(value)
    ids = Upload.where(id: ids).pluck(:id) if ids.any?
    UploadReference.ensure_exist!(upload_ids: ids, target:)
  end

  def self.collect(node, ids)
    case node
    when Hash
      if node["source"] == "upload"
        candidate = node["upload_id"]
        ids << candidate if candidate.is_a?(Integer) && candidate.positive?
      end
      node.each_value { |child| collect(child, ids) }
    when Array
      node.each { |child| collect(child, ids) }
    end
  end
  private_class_method :collect
end
