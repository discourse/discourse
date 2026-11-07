# frozen_string_literal: true

module RspecFileMetadata
  READERS =
    (
      FileTest.singleton_methods(false) +
        %i[stat lstat atime mtime ctime birthtime ftype readlink realpath realdirpath]
    ).uniq.to_h { |name| [name.to_s, File.method(name)] }.freeze
  private_constant :READERS

  def self.method_names
    READERS.keys.map(&:to_sym)
  end

  def self.describe(method:, value:, root: Dir.pwd)
    return unless READERS.key?(method.to_s)
    unless [NilClass, TrueClass, FalseClass, Integer, String].any? { |type| value.is_a?(type) }
      return
    end

    value = value.delete_prefix("#{root}/") if value.is_a?(String)
    { "method" => method.to_s, "value" => value }
  end

  def self.matches?(path:, descriptions:)
    return false unless descriptions.is_a?(Array) && descriptions.any?

    descriptions.all? do |description|
      next false unless description.is_a?(Hash) && description.keys.sort == %w[method value]
      reader = READERS[description["method"]]
      reader && describe(method: description["method"], value: reader.call(path)) == description
    end
  rescue SystemCallError, ArgumentError, TypeError, NotImplementedError
    false
  end
end
