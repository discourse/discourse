# frozen_string_literal: true

require "json"

module YjsTextOperations
  # For Yjs, we'll keep the server-side operations simple
  # The heavy lifting is done on the client side with Yjs
  # Server just stores and passes through the Yjs state

  def self.create_initial_state(content = "")
    # Return a simple initial state that the client can use
    # The client will create the actual Yjs document
    # Return as JSON string since it's stored in a string column
    { content: content, timestamp: Time.current.to_i, version: 1 }.to_json
  end

  def self.merge_updates(updates)
    # For now, just return the last update
    # In a real implementation, you might want to do more sophisticated merging
    updates.last
  end

  def self.get_text_content(doc_state)
    # Extract content from the stored state
    return "" if doc_state.nil?

    # If it's already a hash, check for content field
    return doc_state["content"] || doc_state[:content] || "" if doc_state.is_a?(Hash)

    # If it's a string, try to parse it as JSON
    if doc_state.is_a?(String)
      begin
        parsed = JSON.parse(doc_state)

        # Check if it's the old format with content field
        if parsed.is_a?(Hash) && (parsed["content"] || parsed[:content])
          return parsed["content"] || parsed[:content]
        end

        # If it's an array (binary YJS data), we can't extract text server-side
        # This is YJS binary format, return empty and let client handle it
        if parsed.is_a?(Array)
          Rails.logger.warn "[SharedEdits] Cannot extract text from YJS binary format server-side"
          return ""
        end

        # Unknown format
        return ""
      rescue JSON::ParserError => e
        Rails.logger.error "[SharedEdits] Failed to parse doc_state as JSON: #{e.message}"
        return ""
      end
    end

    # Unknown type
    Rails.logger.warn "[SharedEdits] Unknown doc_state type: #{doc_state.class}"
    ""
  end

  def self.apply_update(doc_state, update)
    # For Yjs, we don't apply updates server-side
    # The client handles all the Yjs operations
    # This is just a placeholder for compatibility
    get_text_content(doc_state)
  end
end
