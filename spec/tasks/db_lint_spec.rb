# frozen_string_literal: true

RSpec.describe "db:lint rake task" do
  def with_temp_tables
    ActiveRecord::Migration.suppress_messages { yield }
  end

  def create_lint_ok_tables
    with_temp_tables do
      ActiveRecord::Base
        .connection
        .create_table(:lint_ok_parents, id: :bigint) { |t| t.timestamps null: true }

      ActiveRecord::Base
        .connection
        .create_table(:lint_ok_children) do |t|
          t.bigint :lint_ok_parent_id
          t.timestamps null: true
        end
    end
  end

  def drop_lint_ok_tables
    with_temp_tables do
      if ActiveRecord::Base.connection.table_exists?(:lint_ok_children)
        ActiveRecord::Base.connection.drop_table(:lint_ok_children)
      end
      if ActiveRecord::Base.connection.table_exists?(:lint_ok_parents)
        ActiveRecord::Base.connection.drop_table(:lint_ok_parents)
      end
    end
  end

  def create_lint_bad_tables
    with_temp_tables do
      ActiveRecord::Base
        .connection
        .create_table(:lint_bad_parents, id: :bigint) { |t| t.timestamps null: true }

      ActiveRecord::Base
        .connection
        .create_table(:lint_bad_children) do |t|
          t.integer :lint_bad_parent_id
          t.timestamps null: true
        end
    end
  end

  def drop_lint_bad_tables
    with_temp_tables do
      if ActiveRecord::Base.connection.table_exists?(:lint_bad_children)
        ActiveRecord::Base.connection.drop_table(:lint_bad_children)
      end
      if ActiveRecord::Base.connection.table_exists?(:lint_bad_parents)
        ActiveRecord::Base.connection.drop_table(:lint_bad_parents)
      end
    end
  end

  after do
    # Clean up any leaked constants
    %i[LintOkParent LintOkChild LintBadParent LintBadChild].each do |const|
      Object.send(:remove_const, const) if Object.const_defined?(const)
    end

    drop_lint_ok_tables
    drop_lint_bad_tables
  end

  it "passes when foreign key types match target primary key types" do
    create_lint_ok_tables

    Object.const_set(
      :LintOkParent,
      Class.new(ActiveRecord::Base) do
        self.table_name = "lint_ok_parents"
        has_many :lint_ok_children, class_name: "LintOkChild", foreign_key: :lint_ok_parent_id
      end,
    )
    Object.const_set(
      :LintOkChild,
      Class.new(ActiveRecord::Base) do
        self.table_name = "lint_ok_children"
        belongs_to :lint_ok_parent, class_name: "LintOkParent"
      end,
    )

    # Limit scan to our test models only (via env var)
    ENV["DB_LINT_ONLY"] = "LintOkParent,LintOkChild"

    # Should not raise SystemExit
    expect { capture_stdout { invoke_rake_task("db:lint") } }.not_to raise_error
  end

  it "fails and reports mismatches when types do not match" do
    create_lint_bad_tables

    Object.const_set(
      :LintBadParent,
      Class.new(ActiveRecord::Base) do
        self.table_name = "lint_bad_parents"
        has_many :lint_bad_children, class_name: "LintBadChild", foreign_key: :lint_bad_parent_id
      end,
    )
    Object.const_set(
      :LintBadChild,
      Class.new(ActiveRecord::Base) do
        self.table_name = "lint_bad_children"
        belongs_to :lint_bad_parent, class_name: "LintBadParent"
      end,
    )

    # Limit scan to our test models only (via env var)
    ENV["DB_LINT_ONLY"] = "LintBadParent,LintBadChild"

    # Should raise SystemExit due to mismatch
    expect { invoke_rake_task("db:lint") }.to raise_error(SystemExit)

    # Capture output to verify helpful message
    output =
      capture_stdout do
        begin
          invoke_rake_task("db:lint")
        rescue SystemExit
          # swallow to capture output
        end
      end

    expect(output).to include("LintBadChild.lint_bad_parent → LintBadParent")
    expect(output).to match(/lint_bad_children\.lint_bad_parent_id is .*integer/i)
    expect(output).to match(/lint_bad_parents\..*bigint/i)
  end
end
