# frozen_string_literal: true

RSpec.describe GroupResource do
  fab!(:group) { Fabricate(:group, name: "a_group") }

  let(:guardian) { Guardian.new }
  let(:glossary) { JsonApiKit::Glossary.resource }
  let(:urls) do
    JsonApiKit::Urls.new(base: "https://example.com/api", current: "https://example.com/api/groups")
  end
  let(:document) do
    JsonApiKit::Document::Individual.for(
      group.id,
      {},
      resource: described_class,
      guardian:,
      urls:,
      glossary:,
    )
  end

  it "shows the name and nothing else" do
    expect(document.to_h[:data]).to eq(
      type: "groups",
      id: group.id.to_s,
      attributes: {
        "name" => "a_group",
      },
      links: {
        self: "https://example.com/api/groups/#{group.id}",
      },
    )
  end
end
