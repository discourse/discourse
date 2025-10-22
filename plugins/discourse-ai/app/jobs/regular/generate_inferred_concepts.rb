# frozen_string_literal: true

module Jobs
  class GenerateInferredConcepts < ::Jobs::Base
    sidekiq_options queue: "low"

    # Process items to generate new concepts
    #
    # @param args [Hash] Contains job arguments
    # @option args [String] :item_type Required - Type of items to process ('topics' or 'posts')
    # @option args [Array<Integer>] :item_ids Required - List of item IDs to process
    # @option args [Integer] :batch_size (100) Number of items to process in each batch
    # @option args [Boolean] :match_only (false) Only match against existing concepts without generating new ones
    def execute(args = {})
      return if args[:item_ids].blank? || args[:item_type].blank?

      if %w[topics posts].exclude?(args[:item_type])
        Rails.logger.error("Invalid item_type for GenerateInferredConcepts: #{args[:item_type]}")
        return
      end

      # Process items in smaller batches to avoid memory issues
      batch_size = args[:batch_size] || 100

      # Get the list of item IDs
      item_ids = args[:item_ids]
      match_only = args[:match_only] || false

      # Process items in batches
      item_ids.each_slice(batch_size) do |batch_item_ids|
        process_batch(batch_item_ids, args[:item_type], match_only)
      end
    end

    private

    def process_batch(item_ids, item_type, match_only)
      klass = item_type.singularize.classify.constantize
      items = klass.where(id: item_ids)
      manager = DiscourseAi::InferredConcepts::Manager.new

      items.each do |item|
        begin
          process_item(item, item_type, match_only, manager)
        rescue => e
          Rails.logger.error(
            "Error generating concepts from #{item_type.singularize} #{item.id}: #{e.message}\n#{e.backtrace.join("\n")}",
          )
        end
      end
    end

    def process_item(item, item_type, match_only, manager)
      # Use the Manager method that handles both identifying and creating concepts
      if match_only
        if item_type == "topics"
          manager.match_topic_to_concepts(item)
        else # posts
          manager.match_post_to_concepts(item)
        end
      else
        if item_type == "topics"
          manager.generate_concepts_from_topic(item)
        else # posts
          manager.generate_concepts_from_post(item)
        end
      end
    end
  end
end
