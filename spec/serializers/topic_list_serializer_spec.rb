# frozen_string_literal: true

RSpec.describe TopicListSerializer do
  fab!(:user)
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, user:, category:) }

  before { topic.allowed_user_ids = [topic.user_id] }

  it "should return the right payload" do
    topic_list = TopicList.new(nil, user, [topic])

    serialized = described_class.new(topic_list, scope: Guardian.new(user)).as_json

    expect(serialized[:users].first[:id]).to eq(topic.user_id)
    expect(serialized[:primary_groups]).to eq([])
    expect(serialized[:topic_list][:topics].first[:id]).to eq(topic.id)
  end

  it "adds filter name to the options hash so childrens can access it" do
    filter = :hot
    topic_list = TopicList.new(filter, user, [topic])

    serializer = described_class.new(topic_list, scope: Guardian.new(user))

    expect(serializer.options[:filter]).to eq(filter)
  end

  describe "has categories" do
    describe "when lazy loading categories enabled" do
      before { SiteSetting.lazy_load_categories_groups = "#{Group::AUTO_GROUPS[:everyone]}" }

      it "serializes categories when lazy loading" do
        topic_list = TopicList.new(nil, user, [topic])
        guardian = Guardian.new(user)

        serialized = described_class.new(topic_list, scope: guardian).as_json

        expect(serialized[:topic_list][:categories].first[:id]).to eq(topic.category.id)
      end

      describe "content localization" do
        fab!(:category_localization) do
          Fabricate(:category_localization, category:, locale: "es", name: "Solicitudes")
        end

        before { category.update!(locale: "en") }

        describe "when enabled" do
          it "returns localized category name and description when locale param is passed" do
            SiteSetting.content_localization_enabled = true
            topic_list = TopicList.new(nil, user, [topic])
            guardian = Guardian.new(user)

            I18n.locale = "es"
            serialized =
              described_class.new(topic_list, scope: guardian, params: { locale: "es" }).as_json

            expect(serialized[:topic_list][:categories].first[:name]).to eq("Solicitudes")
          end
        end

        describe "when disabled" do
          it "returns default category name and description" do
            SiteSetting.content_localization_enabled = false
            topic_list = TopicList.new(nil, user, [topic])
            guardian = Guardian.new(user)

            I18n.locale = "es"
            serialized = described_class.new(topic_list, scope: guardian).as_json

            expect(serialized[:topic_list][:categories].first[:name]).to eq(category.name)
          end
        end
      end
    end

    describe "when lazy loading categories disabled" do
      it "does not serialize categories when not lazy loading" do
        SiteSetting.lazy_load_categories_groups = ""
        topic_list = TopicList.new(nil, user, [topic])
        guardian = Guardian.new(user)

        serialized = described_class.new(topic_list, scope: guardian).as_json

        expect(serialized[:topic_list]).not_to have_key(:categories)
      end
    end
  end
end
