# frozen_string_literal: true

RSpec.describe JsonApiKit::VersionChange::DefaultSorts do
  subject(:default_sorts) { described_class.new(defaults) }

  let(:topic_default) { JsonApiKit::DefaultSort.new(:topics, posted_at: :desc) }
  let(:user_default) { JsonApiKit::DefaultSort.new(:users, username: :asc) }
  let(:defaults) { [topic_default, user_default] }

  describe "#verify!" do
    subject(:verify) { default_sorts.verify! }

    it "accepts one default per resource" do
      expect { verify }.not_to raise_error
    end

    context "when the collection is empty" do
      let(:defaults) { [] }

      it "accepts the collection" do
        expect { verify }.not_to raise_error
      end
    end

    context "when two defaults belong to the same resource" do
      let(:defaults) { [topic_default, JsonApiKit::DefaultSort.new(:topics, title: :asc)] }

      it "reports the conflicting resource" do
        expect { verify }.to raise_error(
          described_class::Conflict,
          "changes the default sort for topics twice.",
        )
      end
    end
  end

  describe "#each_for" do
    subject(:resource_defaults) { default_sorts.each_for(type).to_a }

    let(:type) { "topics" }

    it "yields only the requested resource's default" do
      expect(resource_defaults).to eq([topic_default])
    end

    context "when the resource has no default declaration" do
      let(:type) { "posts" }

      it "returns no defaults" do
        expect(resource_defaults).to be_empty
      end
    end

    context "when the collection is empty" do
      let(:defaults) { [] }

      it "returns no defaults" do
        expect(resource_defaults).to be_empty
      end
    end
  end
end

RSpec.describe JsonApiKit::VersionChange do
  subject(:version_change) { change_class.new("2026-09-01_default_sort.rb") }

  let(:change_class) do
    Class.new(described_class) do
      version "2026-09-01"
      description "Topics use a different default sort."

      resource :topics do
        changed_default_sort from: { posted_at: :desc }
        renamed_sort from: :posted_at, to: :created_at
      end
    end
  end

  describe ".resource" do
    context "when a default declares an invalid direction" do
      subject(:declare_default) do
        change_class.resource(:posts) { changed_default_sort from: { post_number: :sideways } }
      end

      it "rejects the declaration" do
        expect { declare_default }.to raise_error(ArgumentError, /unknown direction: sideways/)
      end
    end
  end

  describe "#current_default_sort" do
    subject(:current_default) { version_change.current_default_sort(default_sort) }

    let(:default_sort) { JsonApiKit::DefaultSort.new(type, posted_at: :desc) }
    let(:type) { "topics" }

    it "translates an existing default's sort names" do
      expect(current_default).to have_attributes(
        type: "topics",
        ordering: {
          "created_at" => :desc,
        },
      )
    end

    context "when the resource type also changes" do
      let(:type) { "discussions" }

      before { change_class.renamed_type from: :discussions, to: :topics }

      it "translates the type before the sort names" do
        expect(current_default).to have_attributes(
          type: "topics",
          ordering: {
            "created_at" => :desc,
          },
        )
      end
    end
  end

  describe "#each_current_default_sort" do
    subject(:default_sorts) { version_change.enum_for(:each_current_default_sort, "topics").to_a }

    it "translates sort names within the declaring change" do
      expect(default_sorts.sole).to have_attributes(
        type: "topics",
        ordering: {
          "created_at" => :desc,
        },
      )
    end

    context "when the change has no default declaration" do
      let(:change_class) { Class.new(described_class) }

      it "returns no default overrides" do
        expect(default_sorts).to be_empty
      end
    end

    context "when type names are reused in the same change" do
      before do
        change_class.renamed_type from: :topics, to: :archives
        change_class.renamed_type from: :discussions, to: :topics
      end

      it "preserves the declaration's current type" do
        expect(default_sorts.sole).to have_attributes(
          type: "topics",
          ordering: {
            "created_at" => :desc,
          },
        )
      end
    end
  end

  describe "#verify!" do
    subject(:verify) { version_change.verify! }

    before { freeze_time(Date.new(2026, 9, 2)) }

    it "accepts one default change per resource" do
      expect { verify }.not_to raise_error
    end

    context "when a resource changes its default twice" do
      before { change_class.resource(:topics) { changed_default_sort from: {} } }

      it "reports the conflicting resource with its source file" do
        expect { verify }.to raise_error(
          ArgumentError,
          "2026-09-01_default_sort.rb changes the default sort for topics twice.",
        )
      end
    end

    context "when two resources change their defaults" do
      before { change_class.resource(:posts) { changed_default_sort from: { post_number: :asc } } }

      it "accepts the independent defaults" do
        expect { verify }.not_to raise_error
      end
    end
  end
end
