module RailsMultisite
  class ConnectionManagement
    CONFIG_FILE = 'config/multisite.yml'

    def self.rails4?
      !!(Rails.version =~ /^4/)
    end

    def self.establish_connection(opts)
      if opts[:db] == "default" && (!defined?(@@default_spec) || !@@default_spec)
        # don't do anything .. handled implicitly
      else
        spec = connection_spec(opts) || @@default_spec
        handler = nil
        if spec != @@default_spec
          handler = @@connection_handlers[spec]
          unless handler
            handler = ActiveRecord::ConnectionAdapters::ConnectionHandler.new
            @@connection_handlers[spec] = handler
          end
        else
          handler = @@default_connection_handler
        end
        ActiveRecord::Base.connection_handler = handler
        if rails4?
          ActiveRecord::Base.connection_handler.establish_connection(ActiveRecord::Base, spec)
        else
          ActiveRecord::Base.connection_handler.establish_connection("ActiveRecord::Base", spec)
        end
      end
    end

    def self.each_connection
      old = current_db
      connected = ActiveRecord::Base.connection_pool.connected?
      all_dbs.each do |db|
        establish_connection(:db => db)
        yield db
        ActiveRecord::Base.connection_handler.clear_active_connections!
      end
      establish_connection(:db => old)
      ActiveRecord::Base.connection_handler.clear_active_connections! unless connected
    end

    def self.all_dbs
      ["default"] +
        if defined?(@@db_spec_cache) && @@db_spec_cache
          @@db_spec_cache.keys.to_a
        else
          []
        end
    end

    def self.current_db
      db = ActiveRecord::Base.connection_pool.spec.config[:db_key] || "default"
    end

    def self.config_filename=(config_filename)
      @@config_filename = config_filename
    end

    def self.config_filename
      @@config_filename ||= File.absolute_path(Rails.root.to_s + "/" + RailsMultisite::ConnectionManagement::CONFIG_FILE)
    end

    def self.current_hostname
      config = ActiveRecord::Base.connection_pool.spec.config
      config[:host_names].nil? ? config[:host] : config[:host_names].first
    end


    def self.clear_settings!
      @@db_spec_cache = nil
      @@host_spec_cache = nil
      @@default_spec = nil
    end

    def self.load_settings!
      spec_klass = rails4? ? ActiveRecord::ConnectionAdapters::ConnectionSpecification : ActiveRecord::Base::ConnectionSpecification
      configs = YAML::load(File.open(self.config_filename))
      configs.each do |k,v|
        raise ArgumentError.new("Please do not name any db default!") if k == "default"
        v[:db_key] = k
      end

      @@db_spec_cache = Hash[*configs.map do |k, data|
        [k, spec_klass::Resolver.new(k, configs).spec]
      end.flatten]

      @@host_spec_cache = {}
      configs.each do |k,v|
        next unless v["host_names"]
        v["host_names"].each do |host|
          @@host_spec_cache[host] = @@db_spec_cache[k]
        end
      end

      @@default_spec = spec_klass::Resolver.new(Rails.env, ActiveRecord::Base.configurations).spec
      ActiveRecord::Base.configurations[Rails.env]["host_names"].each do |host|
        @@host_spec_cache[host] = @@default_spec
      end

      # inject our connection_handler pool
      # WARNING MONKEY PATCH
      #
      # see: https://github.com/rails/rails/issues/8344#issuecomment-10800848
      #
      @@default_connection_handler = ActiveRecord::Base.connection_handler
      ActiveRecord::Base.send :include, NewConnectionHandler if ActiveRecord::VERSION::MAJOR == 3

      ActiveRecord::Base.connection_handler = @@default_connection_handler

      @@connection_handlers = {}
    end

    module NewConnectionHandler
      def self.included(klass)
        klass.class_eval do
          define_singleton_method :connection_handler do
            Thread.current[:connection_handler] || @connection_handler
          end
          define_singleton_method :connection_handler= do |handler|
            @connection_handler ||= handler
            Thread.current[:connection_handler] = handler
          end
        end
      end
    end


    def initialize(app, config = nil)
      @app = app
    end

    def call(env)
      request = Rack::Request.new(env)
      begin

        #TODO: add a callback so users can simply go to a domain to register it, or something
        return [404, {}, ["not found"]] unless @@host_spec_cache[request.host]

        ActiveRecord::Base.connection_handler.clear_active_connections!
        self.class.establish_connection(:host => request['__ws'] || request.host)
        @app.call(env)
      ensure
        ActiveRecord::Base.connection_handler.clear_active_connections!
      end
    end

    def self.connection_spec(opts)
      if opts[:host]
        @@host_spec_cache[opts[:host]]
      else
        @@db_spec_cache[opts[:db]]
      end
    end

  end
end
