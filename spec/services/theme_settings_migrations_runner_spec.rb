# frozen_string_literal: true

describe ThemeSettingsMigrationsRunner do
  fab!(:theme)
  fab!(:migration_field) { Fabricate(:migration_theme_field, version: 1, theme: theme) }
  fab!(:settings_field) { Fabricate(:settings_theme_field, theme: theme, value: <<~YAML) }
      integer_setting: 1
      boolean_setting: true
      string_setting: ""
    YAML

  describe "#run" do
    it "passes values of overridden settings only to migrations" do
      theme.update_setting(:integer_setting, 1)
      theme.update_setting(:string_setting, "osama")
      theme.save!

      migration_field.update!(value: <<~JS)
        export default function migrate(settings) {
          if (settings.get("integer_setting") !== 1) {
            throw new Error(`expected integer_setting to equal 1, but it's actually ${settings.get("integer_setting")}`);
          }
          if (settings.get("string_setting") !== "osama") {
            throw new Error(`expected string_setting to equal "osama", but it's actually "${settings.get("string_setting")}"`);
          }
          if (settings.size !== 2) {
            throw new Error(`expected the settings map to have only 2 keys, but instead got ${settings.size} keys`);
          }
          return settings;
        }
      JS
      results = described_class.new(theme).run
      expect(results.first[:theme_field_id]).to eq(migration_field.id)
      expect(results.first[:settings_before]).to eq(
        { "integer_setting" => 1, "string_setting" => "osama" },
      )
    end

    it "passes values of `objects` typed settings to migrations and the values are parsed (not json string)" do
      settings_field.update!(value: <<~YAML)
        objects_setting:
          type: objects
          default:
            - text: "hello, default link"
              url: "https://google.com"
            - text: "hi, another default link"
              url: "https://discourse.org"
          schema:
            name: link
            properties:
              text:
                type: string
              url:
                type: string
      YAML
      theme.update_setting(
        :objects_setting,
        [{ text: "custom link 1", url: "https://meta.discourse.org" }],
      )
      theme.save!

      migration_field.update!(value: <<~JS)
        export default function migrate(settings) {
          settings.get("objects_setting").push(
            {
              text: "another custom link",
              url: "https://try.discourse.org"
            }
          )
          return settings;
        }
      JS

      results = described_class.new(theme).run

      expect(results.first[:settings_before]).to eq(
        {
          "objects_setting" => [
            { "url" => "https://meta.discourse.org", "text" => "custom link 1" },
          ],
        },
      )
      expect(results.first[:settings_after]).to eq(
        {
          "objects_setting" => [
            { "url" => "https://meta.discourse.org", "text" => "custom link 1" },
            { "url" => "https://try.discourse.org", "text" => "another custom link" },
          ],
        },
      )
    end

    it "passes the output of the previous migration as input to the next one" do
      theme.update_setting(:integer_setting, 1)

      migration_field.update!(value: <<~JS)
        export default function migrate(settings) {
          settings.set("integer_setting", 111);
          return settings;
        }
      JS

      another_migration_field =
        Fabricate(:migration_theme_field, theme: theme, version: 2, value: <<~JS)
        export default function migrate(settings) {
          if (settings.get("integer_setting") !== 111) {
            throw new Error(`expected integer_setting to equal 111, but it's actually ${settings.get("integer_setting")}`);
          }
          settings.set("integer_setting", 222);
          return settings;
        }
      JS

      results = described_class.new(theme).run

      expect(results.size).to eq(2)

      expect(results[0][:theme_field_id]).to eq(migration_field.id)
      expect(results[1][:theme_field_id]).to eq(another_migration_field.id)

      expect(results[0][:settings_before]).to eq({})
      expect(results[0][:settings_after]).to eq({ "integer_setting" => 111 })

      expect(results[1][:settings_before]).to eq({ "integer_setting" => 111 })
      expect(results[1][:settings_after]).to eq({ "integer_setting" => 222 })
    end

    it "doesn't run migrations that have already been ran" do
      Fabricate(:theme_settings_migration, theme: theme, theme_field: migration_field)

      pending_field = Fabricate(:migration_theme_field, theme: theme, version: 23)

      results = described_class.new(theme).run

      expect(results.size).to eq(1)

      expect(results.first[:version]).to eq(23)
      expect(results.first[:theme_field_id]).to eq(pending_field.id)
    end

    it "doesn't error when no migrations have been ran yet" do
      results = described_class.new(theme).run

      expect(results.size).to eq(1)
      expect(results.first[:version]).to eq(1)
      expect(results.first[:theme_field_id]).to eq(migration_field.id)
    end

    it "doesn't error when there are no pending migrations" do
      Fabricate(:theme_settings_migration, theme: theme, theme_field: migration_field)

      results = described_class.new(theme).run

      expect(results.size).to eq(0)
    end

    it "raises an error when there are too many pending migrations" do
      Fabricate(:migration_theme_field, theme: theme, version: 2)

      expect do described_class.new(theme, limit: 1).run end.to raise_error(
        Theme::SettingsMigrationError,
        I18n.t("themes.import_error.migrations.too_many_pending_migrations"),
      )
    end

    it "raises an error if a migration field has a badly formatted name" do
      migration_field.update_attribute(:name, "020-some-name")

      expect do described_class.new(theme).run end.to raise_error(
        Theme::SettingsMigrationError,
        I18n.t("themes.import_error.migrations.invalid_filename", filename: "020-some-name"),
      )

      migration_field.update_attribute(:name, "0020some-name")

      expect do described_class.new(theme).run end.to raise_error(
        Theme::SettingsMigrationError,
        I18n.t("themes.import_error.migrations.invalid_filename", filename: "0020some-name"),
      )

      migration_field.update_attribute(:name, "0020")

      expect do described_class.new(theme).run end.to raise_error(
        Theme::SettingsMigrationError,
        I18n.t("themes.import_error.migrations.invalid_filename", filename: "0020"),
      )
    end

    it "raises an error if a pending migration has version lower than the last ran migration" do
      migration_field.update!(name: "0020-some-name")
      Fabricate(:theme_settings_migration, theme: theme, theme_field: migration_field, version: 20)

      Fabricate(:migration_theme_field, theme: theme, version: 19, name: "0019-failing-migration")

      expect do described_class.new(theme).run end.to raise_error(
        Theme::SettingsMigrationError,
        I18n.t(
          "themes.import_error.migrations.out_of_sequence",
          name: "0019-failing-migration",
          current: 20,
        ),
      )
    end

    it "detects bad syntax in migrations and raises an error" do
      migration_field.update!(value: <<~JS)
        export default function migrate() {
      JS
      expect do described_class.new(theme).run end.to raise_error(
        Theme::SettingsMigrationError,
        I18n.t(
          "themes.import_error.migrations.syntax_error",
          name: "0001-some-name",
          error:
            'SyntaxError: "/discourse/theme/migration: Unexpected token (2:0)\n\n  1 | export default function migrate() {\n> 2 |\n    | ^"',
        ),
      )
    end

    it "imposes memory limit on migrations and raises an error if they exceed the limit" do
      migration_field.update!(value: <<~JS)
        export default function migrate(settings) {
          let a = new Array(10000);
          while(true) {
            a = a.concat(new Array(10000));
          }
          return settings;
        }
      JS

      expect do described_class.new(theme, memory: 10.kilobytes).run end.to raise_error(
        Theme::SettingsMigrationError,
        I18n.t("themes.import_error.migrations.exceeded_memory_limit", name: "0001-some-name"),
      )
    end

    it "imposes time limit on migrations and raises an error if they exceed the limit" do
      migration_field.update!(value: <<~JS)
        export default function migrate(settings) {
          let a = 1;
          while(true) {
            a += 1;
          }
          return settings;
        }
      JS

      expect do described_class.new(theme, timeout: 10).run end.to raise_error(
        Theme::SettingsMigrationError,
        I18n.t("themes.import_error.migrations.timed_out", name: "0001-some-name"),
      )
    end

    it "raises a clear error message when the migration file doesn't export anything" do
      migration_field.update!(value: <<~JS)
        function migrate(settings) {
          return settings;
        }
      JS

      expect do described_class.new(theme).run end.to raise_error(
        Theme::SettingsMigrationError,
        I18n.t("themes.import_error.migrations.no_exported_function", name: "0001-some-name"),
      )
    end

    it "raises a clear error message when the migration file exports the default as something that's not a function" do
      migration_field.update!(value: <<~JS)
        export function migrate(settings) {
          return settings;
        }

        const AA = 1;
        export default AA;
      JS

      expect do described_class.new(theme).run end.to raise_error(
        Theme::SettingsMigrationError,
        I18n.t(
          "themes.import_error.migrations.default_export_not_a_function",
          name: "0001-some-name",
        ),
      )
    end

    it "raises a clear error message when the migration function doesn't return anything" do
      migration_field.update!(value: <<~JS)
        export default function migrate(settings) {}
      JS

      expect do described_class.new(theme).run end.to raise_error(
        Theme::SettingsMigrationError,
        I18n.t("themes.import_error.migrations.no_returned_value", name: "0001-some-name"),
      )
    end

    it "raises a clear error message when the migration function doesn't return a Map" do
      migration_field.update!(value: <<~JS)
        export default function migrate(settings) {
          return {};
        }
      JS

      expect do described_class.new(theme).run end.to raise_error(
        Theme::SettingsMigrationError,
        I18n.t("themes.import_error.migrations.wrong_return_type", name: "0001-some-name"),
      )
    end

    it "surfaces runtime errors that occur within the migration" do
      migration_field.update!(value: <<~JS)
        export default function migrate(settings) {
          null.toString();
          return settings;
        }
      JS

      expect do described_class.new(theme).run end.to raise_error(
        Theme::SettingsMigrationError,
        I18n.t(
          "themes.import_error.migrations.runtime_error",
          name: "0001-some-name",
          error: "TypeError: Cannot read properties of null (reading 'toString')",
        ),
      )
    end

    it "returns a list of objects that each has data representing the migration and the results" do
      results = described_class.new(theme).run

      expect(results[0][:version]).to eq(1)
      expect(results[0][:name]).to eq("some-name")
      expect(results[0][:original_name]).to eq("0001-some-name")
      expect(results[0][:theme_field_id]).to eq(migration_field.id)
      expect(results[0][:settings_before]).to eq({})
      expect(results[0][:settings_after]).to eq({})
    end

    it "attaches the isValidUrl() function to the context of the migrations" do
      theme.update_setting(:string_setting, "https://google.com")
      theme.save!

      migration_field.update!(value: <<~JS)
        export default function migrate(settings, helpers) {
          if (!helpers.isValidUrl("some_invalid_string")) {
            settings.set("string_setting", "is_not_valid_string");
          }

          return settings;
        }
      JS

      results = described_class.new(theme).run

      expect(results[0][:settings_after]).to eq({ "string_setting" => "is_not_valid_string" })
    end

    it "attaches the getCategoryIdByName() function to the context of the migrations" do
      category = Fabricate(:category, name: "Some Category Name")

      theme.update_setting(:integer_setting, -10)
      theme.save!

      migration_field.update!(value: <<~JS)
        export default function migrate(settings, helpers) {
          const categoryId = helpers.getCategoryIdByName("some CatEgory Name");
          settings.set("integer_setting", categoryId);
          return settings;
        }
      JS

      results = described_class.new(theme).run

      expect(results[0][:settings_after]).to eq({ "integer_setting" => category.id })
    end
  end
end
