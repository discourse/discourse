# frozen_string_literal: true
class ThemeModifierSet < ActiveRecord::Base
  class ThemeModifierSetError < StandardError
  end

  belongs_to :theme

  def self.modifiers
    @modifiers ||= self.load_modifiers
  end

  validate :type_validator

  def type_validator
    ThemeModifierSet.modifiers.each do |k, config|
      value = read_attribute(k)
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
    SvgSprite.expire_cache if saved_change_to_svg_icons?
    CSP::Extension.clear_theme_extensions_cache! if saved_change_to_csp_extensions?
  end

  # Given the ids of multiple active themes / theme components, this function
  # will combine them into a 'resolved' behavior
  def self.resolve_modifier_for_themes(theme_ids, modifier_name)
    return nil if !(config = self.modifiers[modifier_name])

    all_values =
      self
        .where(theme_id: theme_ids)
        .where.not(modifier_name => nil)
        .map { |s| s.public_send(modifier_name) }
    case config[:type]
    when :boolean
      all_values.any?
    when :string_array
      all_values.flatten(1)
    else
      raise ThemeModifierSetError "Invalid theme modifier combine_mode"
    end
  end

  def topic_thumbnail_sizes
    array = read_attribute(:topic_thumbnail_sizes)

    return if array.nil?

    array
      .map do |dimension|
        parts = dimension.split("x")
        next if parts.length != 2
        [parts[0].to_i, parts[1].to_i]
      end
      .filter(&:present?)
  end

  def topic_thumbnail_sizes=(val)
    return write_attribute(:topic_thumbnail_sizes, val) if val.nil?
    return write_attribute(:topic_thumbnail_sizes, val) if !val.is_a?(Array)
    if !val.all? { |v| v.is_a?(Array) && v.length == 2 }
      return write_attribute(:topic_thumbnail_sizes, val)
    end

    super(val.map { |dim| "#{dim[0]}x#{dim[1]}" })
  end

  private

  # Build the list of modifiers from the DB schema.
  # This allows plugins to introduce new modifiers by adding columns to the table
  def self.load_modifiers
    hash = {}
    columns_hash.each do |column_name, info|
      next if %w[id theme_id].include?(column_name)

      type = nil
      if info.type == :string && info.array?
        type = :string_array
      elsif info.type == :boolean && !info.array?
        type = :boolean
      else
        if !%i[boolean string].include?(info.type)
          raise ThemeModifierSetError "Invalid theme modifier column type"
        end
      end

      hash[column_name.to_sym] = { type: type }
    end
    hash
  end
end

# == Schema Information
#
# Table name: theme_modifier_sets
#
#  id                       :bigint           not null, primary key
#  theme_id                 :bigint           not null
#  serialize_topic_excerpts :boolean
#  csp_extensions           :string           is an Array
#  svg_icons                :string           is an Array
#  topic_thumbnail_sizes    :string           is an Array
#
# Indexes
#
#  index_theme_modifier_sets_on_theme_id  (theme_id) UNIQUE
#
