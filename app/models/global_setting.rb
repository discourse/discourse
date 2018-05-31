class GlobalSetting

  def self.register(key, default)
    define_singleton_method(key) do
      provider.lookup(key, default)
    end
  end

  VALID_SECRET_KEY ||= /^[0-9a-f]{128}$/
  # this is named SECRET_TOKEN as opposed to SECRET_KEY_BASE
  # for legacy reasons
  REDIS_SECRET_KEY ||= 'SECRET_TOKEN'

  REDIS_VALIDATE_SECONDS ||= 30

  # In Rails secret_key_base is used to encrypt the cookie store
  # the cookie store contains session data
  # Discourse also uses this secret key to digest user auth tokens
  # This method will
  # - use existing token if already set in ENV or discourse.conf
  # - generate a token on the fly if needed and cache in redis
  # - enforce rules about token format falling back to redis if needed
  def self.safe_secret_key_base

    if @safe_secret_key_base && @token_in_redis && (@token_last_validated + REDIS_VALIDATE_SECONDS) < Time.now
      @token_last_validated = Time.now
      token = $redis.without_namespace.get(REDIS_SECRET_KEY)
      if token.nil?
        $redis.without_namespace.set(REDIS_SECRET_KEY, @safe_secret_key_base)
      end
    end

    @safe_secret_key_base ||= begin
      token = secret_key_base
      if token.blank? || token !~ VALID_SECRET_KEY

        @token_in_redis = true
        @token_last_validated = Time.now

        token = $redis.without_namespace.get(REDIS_SECRET_KEY)
        unless token && token =~ VALID_SECRET_KEY
          token = SecureRandom.hex(64)
          $redis.without_namespace.set(REDIS_SECRET_KEY, token)
        end
      end
      if !secret_key_base.blank? && token != secret_key_base
        STDERR.puts "WARNING: DISCOURSE_SECRET_KEY_BASE is invalid, it was re-generated"
      end
      token
    end
  rescue Redis::CommandError => e
    @safe_secret_key_base = SecureRandom.hex(64) if e.message =~ /READONLY/
  end

  def self.load_defaults
    default_provider = FileProvider.from(File.expand_path('../../../config/discourse_defaults.conf', __FILE__))
    default_provider.keys.concat(@provider.keys).uniq.each do |key|
      default = default_provider.lookup(key, nil)

      instance_variable_set("@#{key}_cache", nil)

      define_singleton_method(key) do
        val = instance_variable_get("@#{key}_cache")
        unless val.nil?
          val == :missing ? nil : val
        else
          val = provider.lookup(key, default)
          if val.nil?
            val = :missing
          end
          instance_variable_set("@#{key}_cache", val)
          val == :missing ? nil : val
        end
      end
    end
  end

  def self.use_s3?
    (@use_s3 ||=
      begin
        s3_bucket &&
        s3_region && (
          s3_use_iam_profile || (s3_access_key_id && s3_secret_access_key)
        ) ? :true : :false
      end) == :true
  end

  def self.s3_bucket_name
    @s3_bucket_name ||= s3_bucket.downcase.split("/")[0]
  end

  # for testing
  def self.reset_s3_cache!
    @use_s3 = nil
  end

  def self.database_config
    hash = { "adapter" => "postgresql" }

    %w{
      pool
      connect_timeout
      timeout
      socket
      host
      backup_host
      port
      backup_port
      username
      password
      replica_host
      replica_port
    }.each do |s|
      if val = self.send("db_#{s}")
        hash[s] = val
      end
    end

    hash["adapter"] = "postgresql_fallback" if hash["replica_host"]

    hostnames = [ hostname ]
    hostnames << backup_hostname if backup_hostname.present?

    hostnames << URI.parse(cdn_url).host if cdn_url.present?

    hash["host_names"] = hostnames
    hash["database"] = db_name

    hash["prepared_statements"] = !!self.db_prepared_statements

    { "production" => hash }
  end

  # For testing purposes
  def self.reset_redis_config!
    @config = nil
  end

  def self.redis_config
    @config ||=
      begin
        c = {}
        c[:host] = redis_host if redis_host
        c[:port] = redis_port if redis_port

        if redis_slave_host && redis_slave_port
          c[:slave_host] = redis_slave_host
          c[:slave_port] = redis_slave_port
          c[:connector] = DiscourseRedis::Connector
        end

        c[:password] = redis_password if redis_password.present?
        c[:db] = redis_db if redis_db != 0
        c[:db] = 1 if Rails.env == "test"

        c.freeze
      end
  end

  def self.add_default(name, default)
    unless self.respond_to? name
      define_singleton_method(name) do
        default
      end
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

    def lookup(key, default)
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
      ENV.keys.select { |k| k =~ /^DISCOURSE_/ }.map { |k| k[10..-1].downcase.to_sym }
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

  def self.configure!
    if Rails.env == "test"
      @provider = BlankProvider.new
    else
      @provider =
        FileProvider.from(File.expand_path('../../../config/discourse.conf', __FILE__)) ||
        EnvProvider.new
    end
  end

end
