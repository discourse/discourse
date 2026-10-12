# frozen_string_literal: true

module JsonApiKit
  Client = Data.define(:guardian, :edition, :urls) { delegate :glossary, to: :edition }
end
