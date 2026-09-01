# frozen_string_literal: true

RSpec.describe JsonApiKit::Request::Parameters do
  subject(:declared_parameters) { described_class.new(parameters, glossary:).to_h }

  let(:glossary) { JsonApiKit::Glossary.new([JsonApiKit::Glossary::CasingRule]) }
  let(:parameters) { { "sort" => "-createdAt" } }

  it "converts the sort names" do
    expect(declared_parameters).to eq("sort" => "-created_at")
  end

  context "when the sort is a hash" do
    let(:parameters) { { "sort" => { "createdAt" => :desc } } }

    it "converts the keys only" do
      expect(declared_parameters).to eq("sort" => { "created_at" => :desc })
    end
  end

  context "when the parameters have an include path" do
    let(:parameters) { { "include" => "orderedPosts.lastPoster" } }

    it "converts every segment of the path" do
      expect(declared_parameters).to eq("include" => "ordered_posts.last_poster")
    end
  end

  context "when the parameters have a fieldset" do
    let(:parameters) { { "fields" => { "solved-statuses" => "answeredAt" } } }

    it "converts the field names only" do
      expect(declared_parameters).to eq("fields" => { "solved-statuses" => "answered_at" })
    end
  end

  context "when a filter is named like a parameter" do
    let(:parameters) { { "filter" => { "sort" => "created_at", "anchor" => "SomeValue" } } }

    it "keeps every filter value" do
      expect(declared_parameters).to eq(
        "filter" => {
          "sort" => "created_at",
          "anchor" => "SomeValue",
        },
      )
    end
  end

  context "when a name is not a member name" do
    let(:parameters) { { "sort" => "created_at" } }

    it "raises with the parameter that holds it" do
      expect { declared_parameters }.to raise_error(
        an_instance_of(JsonApiKit::Glossary::CasingRule::NotAMemberName).and(
          having_attributes(source: { parameter: "sort" }),
        ),
      )
    end

    context "when the name is a key" do
      let(:parameters) { { "page" => { "anchor" => { "created_at" => "2026-08-01" } } } }

      it "raises with the parameter that holds it" do
        expect { declared_parameters }.to raise_error(
          having_attributes(source: { parameter: "page[anchor][created_at]" }),
        )
      end
    end
  end

  context "when the parameters have a filter" do
    let(:parameters) { { "filter" => { "postCount" => "SomeTopic Title" } } }

    it "converts the filter name only" do
      expect(declared_parameters).to eq("filter" => { "post_count" => "SomeTopic Title" })
    end
  end

  context "when the parameters have page members" do
    let(:parameters) { { "page" => { "beforeSize" => "1", "after" => "WyJhQiJd" } } }

    it "converts the member names only" do
      expect(declared_parameters).to eq("page" => { "before_size" => "1", "after" => "WyJhQiJd" })
    end
  end

  context "when the parameters anchor on an attribute" do
    let(:parameters) { { "page" => { "anchor" => { "createdAt" => "2026-08-01" } } } }

    it "converts the anchor name only" do
      expect(declared_parameters).to eq("page" => { "anchor" => { "created_at" => "2026-08-01" } })
    end
  end

  context "when the parameters anchor on a computed position" do
    let(:parameters) { { "page" => { "anchor" => "withoutReplies" } } }

    it "converts the anchor name" do
      expect(declared_parameters).to eq("page" => { "anchor" => "without_replies" })
    end
  end
end
