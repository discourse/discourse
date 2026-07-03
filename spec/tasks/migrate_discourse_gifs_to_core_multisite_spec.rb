# frozen_string_literal: true

RSpec.describe "tasks/migrate_discourse_gifs_to_core (multisite)", type: :multisite do
  before { silence_warnings { Discourse::Application.load_tasks } }

  it "migrates each site's component while its own connection is active" do
    migrations = []
    allow(DiscourseGifsMigration).to receive(:find_component_in_db) { |db| db }
    allow(DiscourseGifsMigration).to receive(:migrate_component) do |db, **|
      migrations << [db, RailsMultisite::ConnectionManagement.current_db]
    end

    capture_stdout { DiscourseGifsMigration.migrate_all(enable_gifs: false) }

    expect(migrations).to contain_exactly(%w[default default], %w[second second])
  end
end
