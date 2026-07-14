# frozen_string_literal: true

require Rails.root.join(
          "plugins/discourse-workflows/db/migrate/20260708095336_rename_discourse_workflows_enabled_site_setting",
        )

RSpec.describe RenameDiscourseWorkflowsEnabledSiteSetting do
  subject(:migration) { described_class.new }

  let(:connection) { ActiveRecord::Base.connection }

  around { |example| ActiveRecord::Migration.suppress_messages { example.run } }

  before { delete_workflow_settings }

  after { delete_workflow_settings }

  def delete_workflow_settings
    connection.execute(<<~SQL)
      DELETE FROM site_settings
      WHERE name IN ('discourse_workflows_enabled', 'enable_discourse_workflows')
    SQL
  end

  def store_setting(name, value)
    connection.execute(<<~SQL)
      INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
      VALUES ('#{name}', 5, '#{value}', NOW(), NOW())
    SQL
  end

  def setting_value(name)
    DB.query_single("SELECT value FROM site_settings WHERE name = :name", name: name).first
  end

  it "preserves enabled customer opt-ins" do
    store_setting("discourse_workflows_enabled", "t")

    migration.up

    aggregate_failures do
      expect(setting_value("discourse_workflows_enabled")).to be_nil
      expect(setting_value("enable_discourse_workflows")).to eq("t")
    end
  end

  it "restores the old setting name on rollback" do
    store_setting("enable_discourse_workflows", "t")

    migration.down

    aggregate_failures do
      expect(setting_value("enable_discourse_workflows")).to be_nil
      expect(setting_value("discourse_workflows_enabled")).to eq("t")
    end
  end
end
