# API to wrap up plugin store rows
class PluginStore
  def self.get(plugin_name, key)
    if row = PluginStoreRow.where(plugin_name: plugin_name, key: key).first
      cast_value(row.type_name, row.value)
    end
  end

  def self.set(plugin_name, key, value)
    hash = {plugin_name: plugin_name, key: key}
    row = PluginStoreRow.where(hash).first || row = PluginStoreRow.new(hash)

    row.type_name = determine_type(value)
    # nil are stored as nil
    row.value =
      if row.type_name == "JSON"
        value.to_json
      elsif value
        value.to_s
      end

    row.save
  end

  protected


  def self.determine_type(value)
    value.is_a?(Hash) ? "JSON" : value.class.to_s
  end

  def self.cast_value(type, value)
    case type
    when "Fixnum" then value.to_i
    when "TrueClass", "FalseClass" then value == "true"
    when "JSON" then ActiveSupport::HashWithIndifferentAccess.new(::JSON.parse(value))
    else value
    end
  end
end
