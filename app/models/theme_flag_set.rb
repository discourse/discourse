# frozen_string_literal: true
class ThemeFlagSet < ActiveRecord::Base
  class ThemeFlagSetError < StandardError; end

  belongs_to :theme

  FLAGS ||= {
    serialize_topic_excerpts: { combine_mode: :any, type: :boolean },
    csp_extensions: { combine_mode: :flatten, type: :string_array },
    svg_icons: { combine_mode: :flatten, type: :string_array },
  }

  validate :type_validator

  def type_validator
    FLAGS.each do |k, config|
      value = public_send(k)
      next if value.nil?

      case config[:type]
      when :boolean
        next if [true, false].include?(value)
      when :string_array
        next if value.is_a?(Array) && value.all? { |v| v.is_a?(String) }
      end
      errors.add(k, :invalid)
    end
  end

  after_save do
    if saved_change_to_svg_icons?
      SvgSprite.expire_cache
    end
    if saved_change_to_csp_extensions?
      CSP::Extension.clear_theme_extensions_cache!
    end
  end

  # Given the ids of multiple active themes / theme components, this function
  # will combine them into a 'resolved' behavior
  def self.resolve_flag_for_themes(theme_ids, flag_name)
    return nil if !(config = FLAGS[flag_name])

    all_values = self.where(theme_id: theme_ids).where.not(flag_name => nil).pluck(flag_name)
    case config[:combine_mode]
    when :any
      all_values.any?
    when :flatten
      all_values.flatten(1)
    else
      raise ThemeFlagSetError "Invalid theme flag combine_mode"
    end
  end
end

# == Schema Information
#
# Table name: theme_flag_sets
#
#  id                       :bigint           not null, primary key
#  theme_id                 :bigint           not null
#  serialize_topic_excerpts :boolean
#  csp_extensions           :string           is an Array
#  svg_icons                :string           is an Array
#
# Indexes
#
#  index_theme_flag_sets_on_theme_id  (theme_id) UNIQUE
#
