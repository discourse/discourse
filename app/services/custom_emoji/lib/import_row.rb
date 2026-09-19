# frozen_string_literal: true

class CustomEmoji::ImportRow
  CATEGORY_NEW = "new"
  CATEGORY_IDENTICAL = "identical"
  CATEGORY_INVALID = "invalid"
  CATEGORY_CONFLICT_GROUP = "conflict_group"
  CATEGORY_CONFLICT_IMAGE = "conflict_image"
  CATEGORY_CONFLICT_BOTH = "conflict_both"
  CONFLICT_CATEGORIES = [
    CATEGORY_CONFLICT_GROUP,
    CATEGORY_CONFLICT_IMAGE,
    CATEGORY_CONFLICT_BOTH,
  ].freeze

  attr_reader :index,
              :name,
              :group,
              :filename,
              :errors,
              :category,
              :incoming_url,
              :existing_url,
              :existing_group,
              :upload_id

  def self.from_h(hash)
    hash = hash.deep_symbolize_keys
    new(
      index: hash[:index],
      name: hash[:name].to_s,
      group: CustomEmoji.normalize_group(hash[:group]),
      filename: hash[:filename].to_s,
      errors: Array(hash[:errors]),
      category: hash[:category],
      incoming_url: hash[:incoming_url],
      existing_url: hash[:existing_url],
      existing_group: CustomEmoji.normalize_group(hash[:existing_group]),
      upload_id: hash[:upload_id],
    )
  end

  def initialize(
    index:,
    name:,
    group:,
    filename:,
    errors: [],
    category: nil,
    incoming_url: nil,
    existing_url: nil,
    existing_group: nil,
    upload_id: nil
  )
    @index = index
    @name = name
    @group = group
    @filename = filename
    @errors = errors
    @category = category
    @incoming_url = incoming_url
    @existing_url = existing_url
    @existing_group = existing_group
    @upload_id = upload_id
  end

  def read_attribute_for_serialization(attribute)
    public_send(attribute)
  end

  def invalid?
    category == CATEGORY_INVALID
  end

  def identical?
    category == CATEGORY_IDENTICAL
  end

  def conflict?
    CONFLICT_CATEGORIES.include?(category)
  end

  def display_group
    group || CustomEmoji::DEFAULT_GROUP
  end

  def display_existing_group
    existing_group || CustomEmoji::DEFAULT_GROUP
  end

  def mark_invalid(*messages)
    @errors += messages
    @category = CATEGORY_INVALID
    self
  end

  def stage(upload:, existing_emoji:)
    @upload_id = upload.id
    @incoming_url = upload.url
    @category = classify(upload, existing_emoji)
    self
  end

  def to_h
    {
      index:,
      name:,
      group:,
      filename:,
      errors:,
      category:,
      incoming_url:,
      existing_url:,
      existing_group:,
      upload_id:,
    }
  end

  private

  def classify(upload, existing_emoji)
    return CATEGORY_NEW if existing_emoji.nil?

    @existing_url = existing_emoji.upload&.url
    @existing_group = CustomEmoji.normalize_group(existing_emoji.group)

    group_changed = existing_group != group
    image_changed = existing_emoji.upload&.sha1 != upload.sha1

    if group_changed && image_changed
      CATEGORY_CONFLICT_BOTH
    elsif image_changed
      CATEGORY_CONFLICT_IMAGE
    elsif group_changed
      CATEGORY_CONFLICT_GROUP
    else
      CATEGORY_IDENTICAL
    end
  end
end
