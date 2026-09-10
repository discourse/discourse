# frozen_string_literal: true

module JsonApiKitSpec
  class FirstRuleChange < JsonApiKit::VersionChange
    version "2026-09-15"
    description "The first change."

    resource :topics do
      renamed_attribute from: :posted_at, to: :created_at
    end
  end

  class SecondRuleChange < JsonApiKit::VersionChange
    version "2026-10-01"
    description "The second change."

    resource :topics do
      renamed_attribute from: :created_at, to: :published_at
    end
  end

  class MergeRuleChange < JsonApiKit::VersionChange
    version "2026-09-10"
    description "The `posted_date` and `posted_time` attributes of the topics resource become `posted_at`."

    resource :topics do
      merged_attributes from: %i[posted_date posted_time],
                        to: :posted_at,
                        up: ->(date, time) { "#{date} #{time}" },
                        down: ->(posted_at) { posted_at.to_s.split(" ") }
    end
  end

  class NameToTitleChange < JsonApiKit::VersionChange
    version "2026-09-15"
    description "The `name` attribute of the topics resource is renamed to `title`."

    resource :topics do
      renamed_attribute from: :name, to: :title
    end
  end

  class LabelToNameChange < JsonApiKit::VersionChange
    version "2026-10-01"
    description "The `label` attribute of the topics resource is renamed to `name`."

    resource :topics do
      renamed_attribute from: :label, to: :name
    end
  end
end

RSpec.describe JsonApiKit::Glossary::VersionRule do
  subject(:rule) { described_class.new(version) }

  let(:version) { JsonApiKit::ApiVersion.parse("2026-09-01") }
  let(:first_change) { JsonApiKitSpec::FirstRuleChange.new(__FILE__) }
  let(:second_change) { JsonApiKitSpec::SecondRuleChange.new(__FILE__) }
  let(:changes) { [first_change, second_change] }
  let(:name) { JsonApiKit::Name::Field.new(value:, type: "topics") }
  let(:value) { "posted_at" }

  before { allow(JsonApiKit::VersionChange).to receive(:after).with(version).and_return(changes) }

  describe "#declared_attributes" do
    subject(:declared_attributes) { rule.declared_attributes(attributes) }

    let(:attributes) { { name => "2026-08-01" } }

    it "returns the attributes with their current names" do
      expect(declared_attributes).to eq(name.with(value: "published_at") => "2026-08-01")
    end

    context "when a change merges two of the attributes" do
      let(:changes) { [JsonApiKitSpec::MergeRuleChange.new(__FILE__), first_change, second_change] }
      let(:attributes) { { name => "2026-08-01", name.with(value: "posted_time") => "00:00:00" } }
      let(:value) { "posted_date" }

      it "returns one attribute under the current name" do
        expect(declared_attributes).to eq(name.with(value: "published_at") => "2026-08-01 00:00:00")
      end
    end
  end

  describe "#declared_name" do
    subject(:declared_name) { rule.declared_name(name) }

    it "returns the current name of an old name" do
      expect(declared_name).to eq(name.with(value: "published_at"))
    end

    context "when a later change reuses a spelling of this version" do
      let(:first_change) { JsonApiKitSpec::NameToTitleChange.new(__FILE__) }
      let(:second_change) { JsonApiKitSpec::LabelToNameChange.new(__FILE__) }
      let(:value) { "name" }

      it "returns the current name" do
        expect(declared_name).to eq(name.with(value: "title"))
      end

      context "when the name belongs to a later version" do
        let(:value) { "title" }

        it "raises a correction with the declared name" do
          expect { declared_name }.to raise_error(having_attributes(name:))
        end
      end
    end

    context "when no change touches the name" do
      let(:value) { "title" }

      it "returns the name" do
        expect(declared_name).to eq(name)
      end
    end

    context "when the name is one of several a change merges" do
      let(:changes) { [JsonApiKitSpec::MergeRuleChange.new(__FILE__), first_change, second_change] }
      let(:value) { "posted_time" }

      it "returns the current name" do
        expect(declared_name).to eq(name.with(value: "published_at"))
      end

      context "when the name is the one they merge into" do
        let(:value) { "posted_at" }

        it "raises a correction with the declared name" do
          expect { declared_name }.to raise_error(
            having_attributes(name: name.with(value: "published_at")),
          )
        end
      end
    end

    context "when the name belongs to a later version" do
      let(:value) { "published_at" }

      it "raises a correction with the declared name" do
        expect { declared_name }.to raise_error(
          an_instance_of(JsonApiKit::Glossary::Correction).and(having_attributes(name:)),
        )
      end
    end
  end

  describe "#member_attributes" do
    subject(:member_attributes) { rule.member_attributes(name => "2026-08-01 00:00:00") }

    let(:value) { "published_at" }

    it "returns the attributes with the names of this version" do
      expect(member_attributes).to eq(name.with(value: "posted_at") => "2026-08-01 00:00:00")
    end

    context "when a change merges two names of this version into the attribute" do
      let(:changes) { [JsonApiKitSpec::MergeRuleChange.new(__FILE__), first_change, second_change] }

      it "returns the two attributes under those names" do
        expect(member_attributes).to eq(
          name.with(value: "posted_date") => "2026-08-01",
          name.with(value: "posted_time") => "00:00:00",
        )
      end
    end
  end

  describe "#member_name" do
    subject(:member_name) { rule.member_name(name) }

    let(:value) { "published_at" }

    it "returns the name of this version for a current name" do
      expect(member_name).to eq(name.with(value: "posted_at"))
    end

    context "when no change touches the name" do
      let(:value) { "title" }

      it "returns the name" do
        expect(member_name).to eq(name)
      end
    end

    context "when a change merges several names of this version into the current one" do
      let(:changes) { [JsonApiKitSpec::MergeRuleChange.new(__FILE__), first_change, second_change] }
      let(:value) { "published_at" }

      it "returns the first of them" do
        expect(member_name).to eq(name.with(value: "posted_date"))
      end
    end
  end
end
