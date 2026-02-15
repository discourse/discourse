# frozen_string_literal: true

RSpec.describe Migrations::Database::Schema::DSL::ConfigMigrator do
  def create_yaml_config(dir, config)
    path = File.join(dir, "test_config.yml")
    File.write(path, config.to_yaml)
    path
  end

  describe "#migrate!" do
    it "generates config.rb from output section" do
      Dir.mktmpdir do |tmpdir|
        yaml_path =
          create_yaml_config(
            tmpdir,
            {
              output: {
                schema_file: "db/schema.sql",
                models_directory: "lib/models",
                models_namespace: "Test::Models",
                enums_directory: "lib/enums",
                enums_namespace: "Test::Enums",
              },
              schema: {
                tables: {
                },
              },
            },
          )

        output_path = File.join(tmpdir, "output")
        described_class.new(yaml_path, output_path).migrate!

        config_content = File.read(File.join(output_path, "config.rb"))
        expect(config_content).to include('schema_file "db/schema.sql"')
        expect(config_content).to include('models_directory "lib/models"')
        expect(config_content).to include('models_namespace "Test::Models"')
        expect(config_content).to include('enums_directory "lib/enums"')
        expect(config_content).to include('enums_namespace "Test::Enums"')
      end
    end

    it "generates conventions.rb from global column config" do
      Dir.mktmpdir do |tmpdir|
        yaml_path =
          create_yaml_config(
            tmpdir,
            {
              output: {
                schema_file: "db/schema.sql",
                models_directory: "lib/models",
                models_namespace: "M",
                enums_directory: "lib/enums",
                enums_namespace: "E",
              },
              schema: {
                tables: {
                },
                global: {
                  columns: {
                    modify: [
                      { name: "id", datatype: "numeric", rename_to: "original_id" },
                      { name_regex: ".*_id$", datatype: "numeric" },
                    ],
                    exclude: %w[updated_at],
                  },
                },
              },
            },
          )

        output_path = File.join(tmpdir, "output")
        described_class.new(yaml_path, output_path).migrate!

        content = File.read(File.join(output_path, "conventions.rb"))
        expect(content).to include("column :id do")
        expect(content).to include("rename_to :original_id")
        expect(content).to include("type :numeric")
        expect(content).to include("columns_matching(/.*_id$/)")
        expect(content).to include("ignore_columns :updated_at")
      end
    end

    it "generates ignored.rb from global table exclusions" do
      Dir.mktmpdir do |tmpdir|
        yaml_path =
          create_yaml_config(
            tmpdir,
            {
              output: {
                schema_file: "db/schema.sql",
                models_directory: "lib/models",
                models_namespace: "M",
                enums_directory: "lib/enums",
                enums_namespace: "E",
              },
              schema: {
                tables: {
                },
                global: {
                  tables: {
                    exclude: %w[chat_messages chat_channels api_keys],
                  },
                },
              },
            },
          )

        output_path = File.join(tmpdir, "output")
        described_class.new(yaml_path, output_path).migrate!

        content = File.read(File.join(output_path, "ignored.rb"))
        expect(content).to include("Migrations::Database::Schema.ignored do")
        expect(content).to include("chat_messages")
        expect(content).to include("chat_channels")
        expect(content).to include("api_keys")
      end
    end

    it "generates enum files" do
      Dir.mktmpdir do |tmpdir|
        yaml_path =
          create_yaml_config(
            tmpdir,
            {
              output: {
                schema_file: "db/schema.sql",
                models_directory: "lib/models",
                models_namespace: "M",
                enums_directory: "lib/enums",
                enums_namespace: "E",
              },
              schema: {
                tables: {
                },
                enums: {
                  import_mode: {
                    values: %w[auto override append],
                  },
                  datatype: {
                    source: "::SomeClass.types",
                  },
                },
              },
            },
          )

        output_path = File.join(tmpdir, "output")
        described_class.new(yaml_path, output_path).migrate!

        import_content = File.read(File.join(output_path, "enums", "import_mode.rb"))
        expect(import_content).to include("enum :import_mode do")
        expect(import_content).to include("value :auto, 0")
        expect(import_content).to include("value :override, 1")
        expect(import_content).to include("value :append, 2")

        datatype_content = File.read(File.join(output_path, "enums", "datatype.rb"))
        expect(datatype_content).to include("enum :datatype do")
        expect(datatype_content).to include('source "::SomeClass.types"')
      end
    end

    it "generates table files with include, exclude, add, and modify" do
      Dir.mktmpdir do |tmpdir|
        yaml_path =
          create_yaml_config(
            tmpdir,
            {
              output: {
                schema_file: "db/schema.sql",
                models_directory: "lib/models",
                models_namespace: "M",
                enums_directory: "lib/enums",
                enums_namespace: "E",
              },
              schema: {
                tables: {
                  users: {
                    columns: {
                      include: %w[id username email],
                      add: [{ name: "original_username", datatype: "text" }],
                      modify: [{ name: "created_at", nullable: false }],
                    },
                  },
                },
              },
            },
          )

        output_path = File.join(tmpdir, "output")
        described_class.new(yaml_path, output_path).migrate!

        content = File.read(File.join(output_path, "tables", "users.rb"))
        expect(content).to include("table :users do")
        expect(content).to include("include :id, :username, :email")
        expect(content).to include("add_column :original_username, :text")
        expect(content).to include("column :created_at, required: true")
      end
    end

    it "generates table files with copy_of, primary_key, indexes, and excluded columns" do
      Dir.mktmpdir do |tmpdir|
        yaml_path =
          create_yaml_config(
            tmpdir,
            {
              output: {
                schema_file: "db/schema.sql",
                models_directory: "lib/models",
                models_namespace: "M",
                enums_directory: "lib/enums",
                enums_namespace: "E",
              },
              schema: {
                tables: {
                  user_archive: {
                    copy_of: "users",
                    primary_key_column_names: %w[user_id archive_id],
                    columns: {
                      exclude: %w[secret_token],
                    },
                    indexes: [
                      {
                        name: "idx_archive_user",
                        columns: %w[user_id],
                        unique: true,
                        condition: "WHERE active = TRUE",
                      },
                    ],
                  },
                },
              },
            },
          )

        output_path = File.join(tmpdir, "output")
        described_class.new(yaml_path, output_path).migrate!

        content = File.read(File.join(output_path, "tables", "user_archive.rb"))
        expect(content).to include("copy_structure_from :users")
        expect(content).to include("primary_key :user_id, :archive_id")
        expect(content).to include('ignore :secret_token, "TODO: add reason"')
        expect(content).to include("unique_index :user_id, name: :idx_archive_user")
        expect(content).to include("WHERE active = TRUE")
      end
    end

    it "generates table files for empty table config" do
      Dir.mktmpdir do |tmpdir|
        yaml_path =
          create_yaml_config(
            tmpdir,
            {
              output: {
                schema_file: "db/schema.sql",
                models_directory: "lib/models",
                models_namespace: "M",
                enums_directory: "lib/enums",
                enums_namespace: "E",
              },
              schema: {
                tables: {
                  badge_groupings: {
                  },
                },
              },
            },
          )

        output_path = File.join(tmpdir, "output")
        described_class.new(yaml_path, output_path).migrate!

        content = File.read(File.join(output_path, "tables", "badge_groupings.rb"))
        expect(content).to include("table :badge_groupings do")
        expect(content).to include("end")
      end
    end

    it "creates required directory structure" do
      Dir.mktmpdir do |tmpdir|
        yaml_path =
          create_yaml_config(
            tmpdir,
            {
              output: {
                schema_file: "db/schema.sql",
                models_directory: "lib/models",
                models_namespace: "M",
                enums_directory: "lib/enums",
                enums_namespace: "E",
              },
              schema: {
                tables: {
                },
              },
            },
          )

        output_path = File.join(tmpdir, "output")
        described_class.new(yaml_path, output_path).migrate!

        expect(Dir.exist?(output_path)).to be true
        expect(Dir.exist?(File.join(output_path, "enums"))).to be true
        expect(Dir.exist?(File.join(output_path, "tables"))).to be true
      end
    end

    it "handles added columns with enum references" do
      Dir.mktmpdir do |tmpdir|
        yaml_path =
          create_yaml_config(
            tmpdir,
            {
              output: {
                schema_file: "db/schema.sql",
                models_directory: "lib/models",
                models_namespace: "M",
                enums_directory: "lib/enums",
                enums_namespace: "E",
              },
              schema: {
                tables: {
                  settings: {
                    columns: {
                      add: [{ name: "import_mode", enum: "import_mode_enum", nullable: false }],
                    },
                  },
                },
              },
            },
          )

        output_path = File.join(tmpdir, "output")
        described_class.new(yaml_path, output_path).migrate!

        content = File.read(File.join(output_path, "tables", "settings.rb"))
        expect(content).to include(
          "add_column :import_mode, :import_mode_enum, required: true, enum: :import_mode_enum",
        )
      end
    end
  end
end
