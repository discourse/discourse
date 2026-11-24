# frozen_string_literal: true

RSpec.describe Discourse, type: :multisite do
  def current_database
    ActiveRecord::Base.connection.select_value("SELECT current_database()")
  end

  def with_worker_statement_timeout
    original_config = ActiveRecord::Base.configurations
    original_env = ENV.to_hash
    ENV["DISCOURSE_DB_NAME"] = current_database
    ENV["DISCOURSE_DB_USERNAME"] = ""
    ENV["DISCOURSE_DB_VARIABLES_STATEMENT_TIMEOUT"] = "10s"
    ENV["DISCOURSE_UNICORN_WORKER_DB_VARIABLES_STATEMENT_TIMEOUT"] = "100s"

    allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
    GlobalSetting.configure!(use_blank_provider: false)
    GlobalSetting.load_defaults

    yield
  ensure
    RailsMultisite::ConnectionManagement.establish_connection(db: "default")
    ENV.replace(original_env)
    allow(Rails).to receive(:env).and_call_original
    ActiveRecord::Base.connection_handler.clear_all_connections!(:all)
    ActiveRecord::Base.configurations = original_config
    ActiveRecord::Base.establish_connection
    GlobalSetting.configure!
    GlobalSetting.load_defaults
    %i[db_variables_statement_timeout unicorn_worker_db_variables_statement_timeout].each do |name|
      GlobalSetting.singleton_class.remove_method(name)
    end
  end

  describe ".apply_worker_db_variables_overrides" do
    it "applies overrides to the default database when another tenant is selected" do
      default_database = current_database
      second_database =
        RailsMultisite::ConnectionManagement.with_connection("second") { current_database }

      with_worker_statement_timeout do
        RailsMultisite::ConnectionManagement.establish_connection(db: "second")

        Discourse.apply_worker_db_variables_overrides

        expect(current_database).to eq(default_database)
        expect(ActiveRecord::Base.connection.select_value("SHOW statement_timeout")).to eq("100s")
        RailsMultisite::ConnectionManagement.establish_connection(db: "second")
        expect(current_database).to eq(second_database)
      end
    end
  end

  describe ".reset_worker_db_variables_overrides" do
    it "selects the default database when there are no worker overrides" do
      default_database = current_database
      RailsMultisite::ConnectionManagement.establish_connection(db: "second")

      Discourse.reset_worker_db_variables_overrides

      expect(current_database).to eq(default_database)
    end

    it "keeps tenant databases separate when clearing the worker overrides" do
      default_database = current_database
      second_database =
        RailsMultisite::ConnectionManagement.with_connection("second") { current_database }

      with_worker_statement_timeout do
        Discourse.apply_worker_db_variables_overrides
        RailsMultisite::ConnectionManagement.establish_connection(db: "second")

        Discourse.reset_worker_db_variables_overrides

        expect(current_database).to eq(default_database)
        expect(ActiveRecord::Base.connection.select_value("SHOW statement_timeout")).to eq("10s")
        RailsMultisite::ConnectionManagement.establish_connection(db: "second")
        expect(current_database).to eq(second_database)
      end
    end
  end
end
