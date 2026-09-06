# frozen_string_literal: true

RSpec.describe JsonApiKit::Reflection do
  subject(:reflection) { described_class.for(Topic.reflect_on_association(name)) }

  fab!(:topic) { Fabricate(:topic, title: "A row the kit reflects on") }

  let(:name) { :user }

  describe ".for" do
    it { is_expected.to be_an_instance_of(described_class) }

    context "with a through association" do
      let(:name) { :tags }

      it { is_expected.to be_an_instance_of(described_class::Through) }
    end
  end

  describe "#owner_key" do
    subject(:owner_key) { reflection.owner_key }

    context "with a belongs_to" do
      it { is_expected.to eq(:user_id) }
    end

    context "with a has_many" do
      let(:name) { :posts }

      it { is_expected.to eq(:id) }
    end

    context "with a through association" do
      let(:name) { :tags }

      it { is_expected.to eq(:id) }
    end
  end

  describe "#association" do
    subject(:association) { reflection.association([topic]) }

    it { is_expected.to be_an_instance_of(JsonApiKit::Association) }

    context "with a through association" do
      let(:name) { :tags }

      it { is_expected.to be_an_instance_of(JsonApiKit::Association::Through) }
    end
  end
end
