# frozen_string_literal: true

RSpec.describe Discourse, type: :multisite do
  describe ".apply_db_variables_overrides" do
    around do |example|
      original_env = ENV.to_hash
      original_config = ActiveRecord::Base.configurations
      original_show_statement_timeout =
        ActiveRecord::Base.connection.execute("SHOW statement_timeout").first["statement_timeout"]

      begin
        example.run
      ensure
        ENV.replace(original_env)
        ActiveRecord::Base.configurations = original_config
        ActiveRecord::Base.connection_handler.clear_all_connections!(:all)
        ActiveRecord::Base.establish_connection
        GlobalSetting.configure!
        GlobalSetting.load_defaults

        expect(
          ActiveRecord::Base.connection.execute("SHOW statement_timeout").first[
            "statement_timeout"
          ],
        ).to eq(original_show_statement_timeout)
      end
    end

    it "keeps tenant databases separate when a web worker forks a mold" do
      default_database = ActiveRecord::Base.connection.select_value("SELECT current_database()")
      RailsMultisite::ConnectionManagement.establish_connection(db: "second")
      second_database = ActiveRecord::Base.connection.select_value("SELECT current_database()")
      RailsMultisite::ConnectionManagement.establish_connection(db: "default")
      config_file = Tempfile.new("discourse.conf")
      config_file.write <<~TEXT
        db_name = #{default_database}
        db_username = ""
        db_variables_statement_timeout = 10s
        unicorn_worker_db_variables_statement_timeout = 100s
      TEXT
      config_file.flush
      Rails.stubs(:env).returns(ActiveSupport::StringInquirer.new("production"))
      GlobalSetting.configure!(path: config_file.path, use_blank_provider: false)
      GlobalSetting.load_defaults
      Discourse.apply_db_variables_overrides(web: true)
      RailsMultisite::ConnectionManagement.establish_connection(db: "second")
      reader, writer = IO.pipe

      child =
        fork do
          reader.close
          Discourse.apply_db_variables_overrides(web: false)
          databases =
            %w[default second].map do |db|
              RailsMultisite::ConnectionManagement.establish_connection(db: db)
              ActiveRecord::Base.connection.select_value("SELECT current_database()")
            end
          writer.write(databases.to_json)
          writer.close
          exit!(0)
        end
      writer.close
      _, status = Timeout.timeout(10) { Process.wait2(child) }
      child = nil

      expect(status).to be_success
      expect(JSON.parse(reader.read)).to eq([default_database, second_database])
    ensure
      if child
        begin
          Process.kill("KILL", child)
        rescue StandardError
          nil
        end
        begin
          Process.waitpid(child)
        rescue StandardError
          nil
        end
      end
      reader&.close unless reader&.closed?
      writer&.close unless writer&.closed?
      Discourse.apply_db_variables_overrides(web: false)
      %i[
        db_variables_statement_timeout
        unicorn_worker_db_variables_statement_timeout
      ].each { |method| GlobalSetting.singleton_class.remove_method(method) }
      allow(Rails).to receive(:env).and_call_original
      config_file&.close!
    end
  end
end
