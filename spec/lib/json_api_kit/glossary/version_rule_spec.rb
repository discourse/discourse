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
  let(:name) { JsonApiKit::Name::Field.new(value:, type: "topics") }
  let(:value) { "posted_at" }

  before do
    allow(JsonApiKit::VersionChange).to receive(:after).with(version).and_return(
      [first_change, second_change],
    )
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

      it "returns the current name of the old name" do
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

    context "when the name belongs to a later version" do
      let(:value) { "published_at" }

      it "raises a correction with the declared name" do
        expect { declared_name }.to raise_error(
          an_instance_of(JsonApiKit::Glossary::Correction).and(having_attributes(name:)),
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
  end
end
