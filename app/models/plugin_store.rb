# API to wrap up plugin store rows
class PluginStore
  def self.get(plugin_name, key)
    if row = PluginStoreRow.find_by(plugin_name: plugin_name, key: key)
      cast_value(row.type_name, row.value)
    end
  end

  def self.set(plugin_name, key, value)
    hash = {plugin_name: plugin_name, key: key}
    row = PluginStoreRow.find_by(hash) || PluginStoreRow.new(hash)

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

  def self.remove(plugin_name, key)
    PluginStoreRow.where(plugin_name: plugin_name, key: key).destroy_all
  end

  def self.determine_type(value)
    value.is_a?(Hash) || value.is_a?(Array) ? "JSON" : value.class.to_s
  end

  def self.map_json(item)
    if item.is_a? Hash
      ActiveSupport::HashWithIndifferentAccess.new item
    elsif item.is_a? Array
      item.map { |subitem| map_json subitem}
    else
      item
    end
  end

  def self.cast_value(type, value)
    case type
    when "Fixnum" then value.to_i
    when "TrueClass", "FalseClass" then value == "true"
    when "JSON" then map_json(::JSON.parse(value))
    else value
    end
  end
end
