# frozen_string_literal: true

RSpec.describe DiscourseBoosts::Boost::Show do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:boost_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:user)
    fab!(:boost_author, :user)
    fab!(:topic)
    fab!(:post) { Fabricate(:post, topic:, user: boost_author) }
    fab!(:boost) { Fabricate(:boost, post:, user: boost_author) }

    let(:params) { { boost_id: boost.id } }
    let(:dependencies) { { guardian: user.guardian } }

    context "when contract is invalid" do
      let(:params) { { boost_id: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when boost is not found" do
      let(:params) { { boost_id: 0 } }

      it { is_expected.to fail_to_find_a_model(:boost) }
    end

    context "when user cannot see the post" do
      fab!(:private_category) { Fabricate(:private_category, group: Fabricate(:group)) }
      fab!(:topic) { Fabricate(:topic, category: private_category) }
      fab!(:post) { Fabricate(:post, topic:, user: boost_author) }
      fab!(:boost) { Fabricate(:boost, post:, user: boost_author) }

      it { is_expected.to fail_a_policy(:can_see_boost) }
    end

    context "when everything is valid" do
      it { is_expected.to run_successfully }

      it "returns the boost" do
        expect(result.boost).to eq(boost)
      end
    end
  end
end
