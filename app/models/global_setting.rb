class GlobalSetting

  def self.available_settings(*settings)
    settings.each do |name, desc, default|
      define_singleton_method(name) do
        provider.lookup(name, default)
      end
    end
  end

  def self.generate_sample_file(file)
  end

  available_settings(
      [:db_pool,                "connection pool size", 5],
      [:db_timeout,             "database timeout in milliseconds", 5000],
      [:db_socket,              "socket file used to access db", ""],
      [:db_host,                "host address for db server", "localhost"],
      [:db_port,                "port running db server", 5432],
      [:db_name,                "database name running discourse", "discourse"],
      [:db_username,            "username accessing database", "discourse"],
      [:db_password,            "password used to access the db", ""],
      [:hostname,               "hostname running the forum", "www.example.com"],
      [:smtp_address,           "address of smtp server used to send emails",""],
      [:smtp_port,              "port of smtp server used to send emails", 25],
      [:smtp_domain,            "domain passed to smtp server", ""],
      [:smtp_user_name,         "username for smtp server", ""],
      [:smtp_password,          "password for smtp server", ""],
      [:smtp_enable_start_tls,  "enable TLS encryption for smtp connections", true],
      [:enable_mini_profiler,   "enable MiniProfiler for administrators", true],
      [:cdn_url,                "recommended, cdn used to access assets", ""],
      [:developer_emails,       "comma delimited list of emails that have devloper level access", true],
      [:redis_host,             "redis server address", "localhost"],
      [:redis_port,             "redis server port", 6379],
      [:redis_password,         "redis password", ""]
  )

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
      File.read(@file).split("\n").each do |line|
        if line =~ /([a-z_]+)\s*=\s*(\"([^\"]*)\"|\'([^\']*)\'|[^#]*)/
          @data[$1.strip.to_sym] = ($4 || $3 || $2).strip
        end
      end
    end


    def lookup(key,default)
      resolve(@data[key], default)
    end


    private
    def self.parse(file)
      provider = self.new(file)
      provider.read
      provider
    end
  end

  class EnvProvider < BaseProvider
    def lookup(key, default)
      resolve(ENV["DISCOURSE_" << key.to_s.upcase], default)
    end
  end


  class << self
    attr_accessor :provider
  end

  @provider =
    FileProvider.from(File.expand_path('../../../config/discourse.conf', __FILE__)) ||
    EnvProvider.new
end
