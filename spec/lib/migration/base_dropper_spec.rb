# frozen_string_literal: true

RSpec.describe Migration::BaseDropper do
  describe ".ensure_function_schema!" do
    it "uses an existing schema without requiring database CREATE privileges" do
      role_name = "base_dropper_restricted"

      DB.exec("CREATE ROLE #{role_name}")
      DB.exec("GRANT USAGE ON SCHEMA discourse_functions TO #{role_name}")
      DB.exec("SET ROLE #{role_name}")

      expect(DB.query_single("SELECT has_database_privilege(current_database(), 'CREATE')")).to eq(
        [false],
      )
      expect { described_class.ensure_function_schema! }.not_to raise_error
    ensure
      DB.exec("RESET ROLE")
      DB.exec("DROP OWNED BY #{role_name}")
      DB.exec("DROP ROLE IF EXISTS #{role_name}")
    end
  end
end
