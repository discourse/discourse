# frozen_string_literal: true

RSpec.describe DiscourseTools::CreateTopic do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_presence_of(:raw) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:user) { Fabricate(:user, trust_level: TrustLevel[1]) }
    fab!(:category)

    let(:title) { "A valid topic title for testing" }
    let(:raw) { "This is the body of the test topic with enough content" }
    let(:params) { { title:, raw:, category_id: category.id } }
    let(:options) { {} }
    let(:guardian) { user.guardian }
    let(:dependencies) { { guardian:, options: } }

    context "when contract is invalid" do
      let(:title) { nil }

      it { is_expected.to fail_a_contract }
    end

    context "when user cannot create topic in category" do
      let(:category) { Fabricate(:private_category, group: Fabricate(:group)) }

      it { is_expected.to fail_a_policy(:can_create) }
    end

    context "when PostCreator fails" do
      let(:raw) { "x" }

      it { is_expected.to fail_a_step(:create_post) }
    end

    context "when everything is valid" do
      it { is_expected.to run_successfully }

      it "creates a topic and post" do
        expect { result }.to change(Topic, :count).by(1).and change(Post, :count).by(1)
      end

      it "sets topic attributes from params" do
        result
        post = result[:post]
        expect(post.topic.title).to eq(title)
        expect(post.topic.category_id).to eq(category.id)
        expect(post.topic.user).to eq(user)
      end

      it "sets the post content" do
        result
        expect(result[:post].raw).to eq(raw)
      end

      context "with tags" do
        fab!(:admin)

        let(:options) { { tags: %w[alpha beta] } }
        let(:guardian) { admin.guardian }

        before { SiteSetting.tagging_enabled = true }

        it "applies tags to the topic" do
          result
          expect(result[:post].topic.tags.pluck(:name)).to contain_exactly("alpha", "beta")
        end
      end

      context "with skip_validations" do
        let(:options) { { skip_validations: true } }

        it { is_expected.to run_successfully }
      end
    end
  end
end
