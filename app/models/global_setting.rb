class GlobalSetting

  def self.register(key, default)
    define_singleton_method(key) do
      provider.lookup(key, default)
    end
  end

  def self.load_defaults
    default_provider = FileProvider.from(File.expand_path('../../../config/discourse_defaults.conf', __FILE__))
    default_provider.keys.concat(@provider.keys).uniq.each do |key|
      default = default_provider.lookup(key, nil)
      define_singleton_method(key) do
        provider.lookup(key, default)
      end
    end
  end

  def self.database_config
    hash = {"adapter" => "postgresql"}
    %w{pool timeout socket host port username password}.each do |s|
      if val = self.send("db_#{s}")
        hash[s] = val
      end
    end
    hostnames = [ hostname ]
    hostnames << backup_hostname if backup_hostname.present?

    hash["host_names"] = hostnames
    hash["database"] = db_name

    hash["prepared_statements"] = !!self.db_prepared_statements

    {"production" => hash}
  end

  def self.redis_config
    @config ||=
      begin
        c = {}
        c[:host] = redis_host if redis_host
        c[:port] = redis_port if redis_port
        c[:password] = redis_password if redis_password.present?
        c[:db] = redis_db if redis_db != 0
        c[:db] = 1 if Rails.env == "test"
        if redis_sentinels.present?
          c[:sentinels] = redis_sentinels.split(",").map do |address|
            host,port = address.split(":")
            {host: host, port: port}
          end.to_a
        end
        c.freeze
      end
  end


  class BaseProvider
    def self.coerce(setting)
      return setting == "true" if setting == "true" || setting == "false"
      return $1.to_i if setting.to_s.strip =~ /^([0-9]+)$/
      setting
    end


    def resolve(current, default)
      BaseProvider.coerce(
        if current.present?
          current
        else
          default.present? ? default : nil
        end
      )
    end
  end

  class FileProvider < BaseProvider
    attr_reader :data
    def self.from(file)
      if File.exists?(file)
        parse(file)
      end
    end

    def initialize(file)
      @file = file
      @data = {}
    end

    def read
      ERB.new(File.read(@file)).result().split("\n").each do |line|
        if line =~ /^\s*([a-z_]+[a-z0-9_]*)\s*=\s*(\"([^\"]*)\"|\'([^\']*)\'|[^#]*)/
          @data[$1.strip.to_sym] = ($4 || $3 || $2).strip
        end
      end
    end


    def lookup(key,default)
      var = @data[key]
      resolve(var, var.nil? ? default : "")
    end

    def keys
      @data.keys
    end

    def self.parse(file)
      provider = self.new(file)
      provider.read
      provider
    end

    private_class_method :parse
  end

  class EnvProvider < BaseProvider
    def lookup(key, default)
      var = ENV["DISCOURSE_" << key.to_s.upcase]
      resolve(var , var.nil? ? default : nil)
    end

    def keys
      ENV.keys.select{|k| k =~ /^DISCOURSE_/}.map{|k| k[10..-1].downcase.to_sym}
    end
  end

  class BlankProvider < BaseProvider
    def lookup(key, default)
      default
    end

    def keys
      []
    end
  end


  class << self
    attr_accessor :provider
  end


  if Rails.env == "test"
    @provider = BlankProvider.new
  else
    @provider =
      FileProvider.from(File.expand_path('../../../config/discourse.conf', __FILE__)) ||
      EnvProvider.new
  end

  load_defaults
end
