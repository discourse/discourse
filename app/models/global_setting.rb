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
    def lookup(name, val)
      t = ENV["D_" << name.to_s.upcase]
      if t.present?
        t
      else
        val.present? ? val : nil
      end
    end
  end

  class FileProvider
    def self.from(location)
    end
  end

  class EnvProvider
  end


  class << self
    attr_accessor :provider
  end

  @provider =
    FileProvider.from(Rails.root + '/config/discourse.conf') ||
    EnvProvider.new
end
