# frozen_string_literal: true

# Creates multiple tags in bulk and returns detailed results for each tag.
# Tags can be successfully created, already exist, or fail validation.
#
# @example
#  Tags::BulkCreate.call(
#    guardian: guardian,
#    params: {
#      tag_names: ["tag1", "tag2", "existing-tag"]
#    }
#  )
#
class Tags::BulkCreate
  include Service::Base

  # @!method self.call(guardian:, params:)
  #   @param [Guardian] guardian
  #   @param [Hash] params
  #   @option params [Array<String>] :tag_names Array of tag names to create (max 100)
  #   @return [Service::Base::Context] context with :results containing created, existing, and failed tags

  policy :can_admin_tags

  params do
    attribute :tag_names, :array

    validates :tag_names,
              length: {
                maximum: 100,
                message: ->(object, data) { I18n.t("tags.bulk_create.too_many_tags", count: 100) },
              },
              if: -> { tag_names.present? }

    validate :tag_names_must_be_array

    def tag_names_must_be_array
      raw_value = @attributes["tag_names"].value_before_type_cast
      if raw_value.nil?
        errors.add(:tag_names, I18n.t("tags.bulk_create.invalid_params"))
        return
      end
      return if raw_value.is_a?(Array)
      errors.add(:tag_names, I18n.t("tags.bulk_create.invalid_params"))
    end
  end

  step :extract_raw_tag_names
  step :normalize_tags
  step :create_tags

  private

  def can_admin_tags(guardian:)
    guardian.can_admin_tags?
  end

  def extract_raw_tag_names(params:)
    raw_values = params.instance_variable_get(:@attributes)["tag_names"].value_before_type_cast
    context[:raw_tag_names] = raw_values.map(&:to_s) if raw_values.is_a?(Array)
  end

  def normalize_tags(raw_tag_names:)
    results = { created: [], existing: [], failed: {} }
    validated_tags = []

    raw_tag_names.each do |raw_name|
      next if raw_name.blank?

      normalized_input = raw_name.strip
      normalized_input = normalized_input.downcase if SiteSetting.force_lowercase_tags
      normalized_input = normalized_input.gsub(/[[:space:]]+/, "-")

      if normalized_input.length > SiteSetting.max_tag_length
        results[:failed][raw_name] = I18n.t(
          "tags.bulk_create.tag_too_long",
          count: SiteSetting.max_tag_length,
        )
        next
      end

      tag_name = DiscourseTagging.clean_tag(raw_name)

      if tag_name.blank?
        results[:failed][raw_name] = I18n.t("tags.bulk_create.invalid_name")
        next
      end

      if tag_name != normalized_input
        results[:failed][raw_name] = I18n.t("tags.bulk_create.invalid_name")
        next
      end

      validated_tags << { raw_name: raw_name, tag_name: tag_name }
    end

    context[:validated_tags] = validated_tags
    context[:results] = results
  end

  def create_tags(validated_tags:, results:)
    tag_names = validated_tags.map { |t| t[:tag_name] }
    existing_tag_names = Tag.where(name: tag_names).pluck(:name).to_set

    validated_tags.each do |tag_info|
      tag_name = tag_info[:tag_name]
      raw_name = tag_info[:raw_name]

      if existing_tag_names.include?(tag_name)
        results[:existing] << tag_name
      else
        tag = Tag.new(name: tag_name)
        if tag.save
          results[:created] << tag_name
        else
          results[:failed][raw_name] = tag.errors.full_messages.join(", ")
        end
      end
    end
  end
end
