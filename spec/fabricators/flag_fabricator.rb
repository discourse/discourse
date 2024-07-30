# frozen_string_literal: true

Fabricator(:flag) { name "offtopic", applies_to { %w[Post Chat::Message] } }
