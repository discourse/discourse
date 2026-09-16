# frozen_string_literal: true

module JsonApiKit
  Client =
    Data.define(:guardian, :edition, :urls) { delegate :glossary, :default_sorts, to: :edition }
end
