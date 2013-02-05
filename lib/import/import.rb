require_dependency 'import/adapter/base'

module Import

  class UnsupportedExportSource   < RuntimeError; end
  class FormatInvalidError        < RuntimeError; end
  class FilenameMissingError      < RuntimeError; end
  class ImportInProgressError     < RuntimeError; end
  class ImportDisabledError       < RuntimeError; end
  class UnsupportedSchemaVersion  < RuntimeError; end
  class WrongTableCountError      < RuntimeError; end
  class WrongFieldCountError      < RuntimeError; end

  def self.import_running_key
    'importer_is_running'
  end

  def self.is_import_running?
    $redis.get(import_running_key) == '1'
  end

  def self.set_import_started
    $redis.set import_running_key, '1'
  end

  def self.set_import_is_not_running
    $redis.del import_running_key
  end


  def self.clear_adapters
    @adapters = {}
    @adapter_instances = {}
  end

  def self.add_import_adapter(klass, version, tables)
    @adapters ||= {}
    @adapter_instances ||= {}
    unless @adapter_instances[klass]
      @adapter_instances[klass] = klass.new
      tables.each do |table|
        @adapters[table.to_s] ||= []
        @adapters[table.to_s] << [version, @adapter_instances[klass]]
      end
    end
  end

  def self.adapters_for_version(version)
    a = Hash.new([])
    @adapters.each {|table_name,adapters| a[table_name] = adapters.reject {|i| i[0].to_i <= version.to_i}.map {|j| j[1]} } if defined?(@adapters)
    a
  end

end