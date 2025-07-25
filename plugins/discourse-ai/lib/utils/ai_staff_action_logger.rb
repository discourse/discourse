# frozen_string_literal: true

module DiscourseAi
  module Utils
    class AiStaffActionLogger
      ## Maximum length for text fields before truncation/simplification
      MAX_TEXT_LENGTH = 100

      def initialize(current_user)
        @current_user = current_user
        @staff_logger = ::StaffActionLogger.new(current_user)
      end

      ## Logs the creation of an AI entity (LLM model or persona)
      ## @param entity_type [Symbol] The type of AI entity being created
      ## @param entity [Object] The entity object being created
      ## @param field_config [Hash] Configuration for how to handle different entity fields
      ## @param entity_details [Hash] Additional details about the entity to be logged
      def log_creation(entity_type, entity, field_config = {}, entity_details = {})
        # Start with provided entity details (id, name, etc.)
        # Convert all keys to strings for consistent handling in StaffActionLogger
        log_details = {}

        # Extract subject for StaffActionLogger.base_attrs
        subject =
          entity_details[:subject] ||
            (entity.respond_to?(:display_name) ? entity.display_name : nil)

        # Add the entity details but preserve subject as a top-level attribute
        entity_details.each { |k, v| log_details[k.to_s] = v unless k == :subject }

        # Extract attributes based on field configuration and ensure string keys
        extract_entity_attributes(entity, field_config).each do |key, value|
          log_details[key.to_s] = value
        end

        @staff_logger.log_custom("create_ai_#{entity_type}", log_details.merge(subject: subject))
      end

      ## Logs an update to an AI entity with before/after comparison
      ## @param entity_type [Symbol] The type of AI entity being updated
      ## @param entity [Object] The entity object after update
      ## @param initial_attributes [Hash] The attributes of the entity before update
      ## @param field_config [Hash] Configuration for how to handle different entity fields
      ## @param entity_details [Hash] Additional details about the entity to be logged
      def log_update(
        entity_type,
        entity,
        initial_attributes,
        field_config = {},
        entity_details = {}
      )
        current_attributes = entity.attributes
        changes = {}

        # Process changes based on field configuration
        field_config
          .except(:json_fields)
          .each do |field, options|
            # Skip if field is not to be tracked
            next if options[:track] == false

            initial_value = initial_attributes[field.to_s]
            current_value = current_attributes[field.to_s]

            # Only process if there's an actual change
            if initial_value != current_value
              # Format the change based on field type
              changes[field.to_s] = format_field_change(
                field,
                initial_value,
                current_value,
                options,
              )
            end
          end

        # Process simple JSON fields (arrays, hashes) that should be tracked as "updated"
        if field_config[:json_fields].present?
          field_config[:json_fields].each do |field|
            field_str = field.to_s
            if initial_attributes[field_str].to_s != current_attributes[field_str].to_s
              changes[field_str] = I18n.t("discourse_ai.ai_staff_action_logger.updated")
            end
          end
        end

        # Only log if there are actual changes
        if changes.any?
          # Extract subject for StaffActionLogger.base_attrs
          subject =
            entity_details[:subject] ||
              (entity.respond_to?(:display_name) ? entity.display_name : nil)

          log_details = {}
          # Convert entity_details keys to strings, but preserve subject as a top-level attribute
          entity_details.each { |k, v| log_details[k.to_s] = v unless k == :subject }
          # Merge changes (already with string keys)
          log_details.merge!(changes)

          @staff_logger.log_custom("update_ai_#{entity_type}", log_details.merge(subject: subject))
        end
      end

      ## Logs the deletion of an AI entity
      ## @param entity_type [Symbol] The type of AI entity being deleted
      ## @param entity_details [Hash] Details about the entity being deleted
      def log_deletion(entity_type, entity_details)
        # Extract subject for StaffActionLogger.base_attrs
        subject = entity_details[:subject]

        # Convert all keys to strings for consistent handling in StaffActionLogger
        string_details = {}
        entity_details.each { |k, v| string_details[k.to_s] = v unless k == :subject }

        @staff_logger.log_custom("delete_ai_#{entity_type}", string_details.merge(subject: subject))
      end

      ## Direct custom logging for complex cases
      ## @param action_type [String] The type of action being logged
      ## @param log_details [Hash] Details to be logged
      def log_custom(action_type, log_details)
        # Extract subject for StaffActionLogger.base_attrs if present
        subject = log_details[:subject]

        # Convert all keys to strings for consistent handling in StaffActionLogger
        string_details = {}
        log_details.each { |k, v| string_details[k.to_s] = v unless k == :subject }

        @staff_logger.log_custom(action_type, string_details.merge(subject: subject))
      end

      private

      ## Formats the change in a field's value for logging
      ## @param field [Symbol] The field that changed
      ## @param initial_value [Object] The original value
      ## @param current_value [Object] The new value
      ## @param options [Hash] Options for formatting
      ## @return [String] Formatted representation of the change
      def format_field_change(field, initial_value, current_value, options = {})
        if options[:type] == :sensitive
          return format_sensitive_field_change(initial_value, current_value)
        elsif options[:type] == :large_text ||
              (initial_value.is_a?(String) && initial_value.length > MAX_TEXT_LENGTH) ||
              (current_value.is_a?(String) && current_value.length > MAX_TEXT_LENGTH)
          return I18n.t("discourse_ai.ai_staff_action_logger.updated")
        end

        # Default formatting: "old_value → new_value"
        "#{initial_value} → #{current_value}"
      end

      ## Formats changes to sensitive fields without exposing actual values
      ## @param initial_value [Object] The original value
      ## @param current_value [Object] The new value
      ## @return [String] Description of the change (updated/set/removed)
      def format_sensitive_field_change(initial_value, current_value)
        if initial_value.present? && current_value.present?
          I18n.t("discourse_ai.ai_staff_action_logger.updated")
        elsif current_value.present?
          I18n.t("discourse_ai.ai_staff_action_logger.set")
        else
          I18n.t("discourse_ai.ai_staff_action_logger.removed")
        end
      end

      ## Extracts relevant attributes from an entity based on field configuration
      ## @param entity [Object] The entity to extract attributes from
      ## @param field_config [Hash] Configuration for how to handle different entity fields
      ## @return [Hash] The extracted attributes
      def extract_entity_attributes(entity, field_config)
        result = {}
        field_config.each do |field, options|
          # Skip special keys like :json_fields which are arrays, not field configurations
          next if field == :json_fields

          # Skip if options is not a hash or if explicitly marked as not to be extracted
          next if !options.is_a?(Hash) || options[:extract] == false

          # Get the actual field value
          field_sym = field.to_sym
          value = entity.respond_to?(field_sym) ? entity.public_send(field_sym) : nil

          # Apply field-specific handling
          if options[:type] == :sensitive
            result[field] = value.present? ? "[FILTERED]" : nil
          elsif options[:type] == :large_text && value.is_a?(String) &&
                value.length > MAX_TEXT_LENGTH
            result[field] = value.truncate(MAX_TEXT_LENGTH)
          else
            result[field] = value
          end
        end

        # Always include dimensions if it exists on the entity
        # This is important for embeddings which are tested for dimensions value
        if entity.respond_to?(:dimensions) && !result.key?(:dimensions)
          result[:dimensions] = entity.dimensions
        end

        result
      end
    end
  end
end
