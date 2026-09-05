# frozen_string_literal: true

RSpec.describe UserResource do
  fab!(:user) { Fabricate(:user, username: "someone") }

  let(:guardian) { Guardian.new }
  let(:glossary) { JsonApiKit::Glossary.resource }
  let(:urls) do
    JsonApiKit::Urls.new(base: "https://example.com/api", current: "https://example.com/api/users")
  end
  let(:document) do
    JsonApiKit::Document::Individual.for(
      user.id,
      {},
      resource: described_class,
      guardian:,
      urls:,
      glossary:,
    )
  end

  it "shows the username and nothing else" do
    expect(document.to_h[:data]).to eq(
      type: "users",
      id: user.id.to_s,
      attributes: {
        "username" => "someone",
      },
      links: {
        self: "https://example.com/api/users/#{user.id}",
      },
    )
  end
end
