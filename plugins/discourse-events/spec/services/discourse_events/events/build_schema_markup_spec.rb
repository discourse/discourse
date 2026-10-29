# frozen_string_literal: true

RSpec.describe DiscourseEvents::Events::BuildSchemaMarkup do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:topic_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:user)
    fab!(:topic) { Fabricate(:topic_with_op, user:, title: "Community hangout") }
    fab!(:event) { Fabricate(:event, post: topic.first_post) }

    let(:params) { { topic_id: } }
    let(:dependencies) { { guardian: } }
    let(:topic_id) { topic.id }
    let(:guardian) { user.guardian }

    before do
      SiteSetting.enable_event_schema_for_topics = true
      SiteSetting.discourse_post_event_enabled = true
    end

    context "without a topic ID" do
      let(:topic_id) { nil }

      it { is_expected.to fail_a_contract }
    end

    context "when event schema markup is disabled" do
      before { SiteSetting.enable_event_schema_for_topics = false }

      it { is_expected.to fail_a_policy(:schema_markup_enabled) }
    end

    context "when post events are disabled" do
      before { SiteSetting.discourse_post_event_enabled = false }

      it { is_expected.to fail_a_policy(:schema_markup_enabled) }
    end

    context "when the topic does not exist" do
      let(:topic_id) { 0 }

      it { is_expected.to fail_to_find_a_model(:topic) }
    end

    context "when the user cannot see the topic" do
      fab!(:private_group, :group)
      fab!(:private_category) { Fabricate(:private_category, group: private_group) }
      fab!(:private_author, :user)
      fab!(:private_topic) do
        Fabricate(:topic_with_op, user: private_author, category: private_category)
      end

      let(:topic_id) { private_topic.id }

      it { is_expected.to fail_a_policy(:can_see_topic) }
    end

    context "when the topic has no first post" do
      fab!(:empty_topic, :topic)

      let(:topic_id) { empty_topic.id }

      it { is_expected.to fail_to_find_a_model(:first_post) }
    end

    context "when the first post has no event" do
      fab!(:ordinary_topic, :topic_with_op)

      let(:topic_id) { ordinary_topic.id }

      it { is_expected.to fail_to_find_a_model(:event) }
    end

    context "with a deleted event" do
      before { event.update_column(:deleted_at, 1.day.ago) }

      it { is_expected.to fail_to_find_a_model(:event) }
    end

    context "when the event is eligible" do
      it { is_expected.to run_successfully }

      it "generates JSON with the loaded event models and wraps it in a script element" do
        json = MultiJson.dump("name" => "Community hangout")
        DiscourseEvents::Events::Action::GenerateSchemaJson
          .expects(:call)
          .with(topic:, first_post: topic.first_post, event:)
          .returns(json)

        expect(result[:html]).to eq(
          "<script type=\"application/ld+json\">#{ERB::Util.json_escape(json)}</script>",
        )
      end

      it "safely embeds unsafe JSON data in one script element" do
        unsafe_name = "Community meetup </script><script>alert('hello')</script>"
        json = MultiJson.dump("name" => unsafe_name)
        DiscourseEvents::Events::Action::GenerateSchemaJson.stubs(:call).returns(json)

        fragment = Nokogiri::HTML5.fragment(result[:html])
        script = fragment.at_css('script[type="application/ld+json"]')

        expect(fragment.css('script[type="application/ld+json"]').count).to eq(1)
        expect(JSON.parse(script.text)["name"]).to eq(unsafe_name)
      end
    end
  end
end
