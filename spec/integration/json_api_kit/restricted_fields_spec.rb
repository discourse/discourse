# frozen_string_literal: true

require_relative "support"

RSpec.describe "a restricted field" do
  include_context "with a listing of topics"

  describe "an attribute" do
    context "when the rule only looks at the user" do
      let(:resource) do
        Class.new(JsonApiKit::Resource) do
          model Topic
          type :topics
          attribute :title
          attribute :created_at, readable: ->(guardian) { guardian.is_admin? }
        end
      end
      let(:title_only) do
        {
          data: [
            topic_object(oldest, fields: %w[title]),
            topic_object(middle, fields: %w[title]),
            topic_object(newest, fields: %w[title]),
          ],
          included: [],
          links: links_of,
        }
      end

      context "when it’s not readable by the user" do
        it "does not render it" do
          expect(document).to eq(title_only)
        end
      end

      context "when an unreadable field is explicitly requested" do
        let(:params) { { fields: { topics: %w[title created_at] } } }

        it "does not render it" do
          expect(document).to eq(title_only)
        end
      end

      context "when it’s readable by the user" do
        let(:guardian) { Fabricate(:admin).guardian }

        it "renders it" do
          expect(document).to eq(
            data: [topic_object(oldest), topic_object(middle), topic_object(newest)],
            included: [],
            links: links_of,
          )
        end
      end
    end

    context "when the rule looks both at the user and the record" do
      let(:resource) do
        Class.new(JsonApiKit::Resource) do
          model Topic
          type :topics
          attribute :title
          attribute :created_at,
                    readable: ->(guardian, topic) { topic.user_id == guardian.user&.id }
        end
      end
      let(:guardian) { middle.user.guardian }

      context "when using sparse fieldsets excluding the one used in the rule" do
        let(:params) { { fields: { topics: %w[title created_at] } } }

        it "does not crash" do
          expect(document[:data].map { it[:attributes].keys }).to eq(
            [%w[title], %w[title created_at], %w[title]],
          )
        end
      end

      it "renders it on the user’s own record alone" do
        expect(document).to eq(
          data: [
            topic_object(oldest, fields: %w[title]),
            topic_object(middle),
            topic_object(newest, fields: %w[title]),
          ],
          included: [],
          links: links_of,
        )
      end
    end
  end

  describe "a relationship" do
    let(:resource) do
      Class.new(JsonApiKit::Resource) do
        model Topic
        type :topics
        attribute :title
        has_one :user,
                resource: JsonApiKitSpec::UserResource,
                readable: ->(guardian) { guardian.is_admin? }
      end
    end
    let(:scoped_to) { Topic.where(id: middle.id) }
    let(:params) { { include: %w[user] } }

    context "when it’s not readable by the user" do
      it "does not render it" do
        expect(document).to eq(
          data: [topic_object(middle, fields: %w[title])],
          included: [],
          links: links_of,
        )
      end
    end

    context "when it’s readable by the user" do
      let(:guardian) { Fabricate(:admin).guardian }

      it "renders it" do
        expect(document).to eq(
          data: [
            topic_object(
              middle,
              fields: %w[title],
              relationships: {
                "user" =>
                  relationship_object(
                    "topics",
                    middle,
                    "user",
                    data: identifier_of("users", middle.user),
                  ),
              },
            ),
          ],
          included: [user_object(middle.user)],
          links: links_of,
        )
      end
    end
  end
end
