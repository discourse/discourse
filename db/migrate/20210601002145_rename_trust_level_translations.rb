# frozen_string_literal: true

class RenameTrustLevelTranslations < ActiveRecord::Migration[6.1]
  KEYS = %w[newuser basic member regular leader].freeze

  def up
    KEYS.each { |key| execute <<~SQL }
        UPDATE translation_overrides
        SET translation_key = 'js.trust_levels.names.#{key}'
        WHERE translation_key = 'trust_levels.#{key}.title'
      SQL
  end

  def down
    KEYS.each { |key| execute <<~SQL }
        UPDATE translation_overrides
        SET translation_key = 'trust_levels.#{key}.title'
        WHERE translation_key = 'js.trust_levels.names.#{key}'
      SQL
  end
end
