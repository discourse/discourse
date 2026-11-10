# frozen_string_literal: true

require Rails.root.join(
          "plugins/discourse-data-explorer/db/post_migrate/20261015121116_delete_stored_custom_data_explorer_tag.rb",
        )

RSpec.describe DeleteStoredCustomDataExplorerTag do
  fab!(:query)

  let(:bundled_query) { DiscourseDataExplorer::Query.find(-1).tap(&:save!) }

  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
  end

  after { ActiveRecord::Migration.verbose = @original_verbose }

  def store_tags(query, names)
    DiscourseDataExplorer::QueryTag
      .resolve_or_create!(names)
      .each do |tag|
        DiscourseDataExplorer::QueryTagMapping.create!(query_id: query.id, query_tag_id: tag.id)
      end
  end

  it "deletes the stored custom tag and its mappings, keeping other tags" do
    store_tags(query, %w[custom staff])
    store_tags(bundled_query, %w[custom staff])

    described_class.new.up

    expect(DiscourseDataExplorer::QueryTag.pluck(:name)).to contain_exactly("staff")
    expect(query.reload.tags.map(&:name)).to eq(["staff"])
    expect(bundled_query.reload.tags.map(&:name)).to eq(["staff"])
  end
end
