# frozen_string_literal: true

module Chat
  class MessageBlocksValidator < ActiveModel::Validator
    def validate(record)
      # ensures we don't validate on read
      return unless record.new_record? || record.changed?

      return if !record.blocks

      schemer = JSONSchemer.schema(Chat::Schemas::MessageBlocks)
      if !schemer.valid?(record.blocks)
        record.errors.add(:blocks, schemer.validate(record.blocks).map { _1.fetch("error") })
        return
      end

      block_ids = Set.new
      action_ids = Set.new
      record.blocks.each do |block|
        block_id = block["block_id"]
        if block_ids.include?(block_id)
          record.errors.add(:blocks, "have duplicated block_id: #{block_id}")
          next
        end
        block_ids.add(block_id)

        block["elements"].each do |element|
          action_id = element["action_id"]
          next unless action_id
          if action_ids.include?(action_id)
            record.errors.add(:blocks, "have duplicated action_id: #{action_id}")
            next
          end
          action_ids.add(action_id)
        end
      end
    end
  end
end
