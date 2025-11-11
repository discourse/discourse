# frozen_string_literal: true

RSpec.describe "AI Post helper", type: :system do
  fab!(:user, :admin)
  fab!(:non_member_group, :group)
  fab!(:topic)
  fab!(:category)
  fab!(:category_2, :category)
  fab!(:post) do
    Fabricate(
      :post,
      topic: topic,
      raw:
        "I like to eat pie. It is a very good dessert. Some people are wasteful by throwing pie at others but I do not do that. I always eat the pie.",
    )
  end
  fab!(:post_2) do
    Fabricate(
      :post,
      topic: topic,
      raw: "I prefer to eat croissants. They are my personal favorite dessert!",
    )
  end
  fab!(:post_3) do
    Fabricate(
      :post,
      topic: topic,
      raw: "I disagree with both of you, I think cake is the best dessert.",
    )
  end
  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:suggestion_menu) { PageObjects::Components::AiSplitTopicSuggester.new }
  fab!(:video, :tag)
  fab!(:music, :tag)
  fab!(:cloud, :tag)
  fab!(:feedback, :tag)
  fab!(:review, :tag)
  fab!(:embedding_definition)

  before do
    enable_current_plugin
    Group.find_by(id: Group::AUTO_GROUPS[:admins]).add(user)
    assign_fake_provider_to(:ai_default_llm_model)
    SiteSetting.ai_helper_enabled = true
    sign_in(user)
  end

  def open_move_topic_modal
    topic_page.visit_topic(topic)
    find(".topic-timeline .toggle-admin-menu").click
    find(".topic-admin-multi-select .btn").click
    find("#post_2 .select-posts .select-below").click
    find(".move-to-topic").click
  end

  describe "moving posts to a new topic" do
    context "when suggesting titles with AI title suggester" do
      let(:mode) { DiscourseAi::AiHelper::Assistant::GENERATE_TITLES }
      let(:titles) do
        {
          output: [
            "Pie: A delicious dessert",
            "Cake is the best!",
            "Croissants are delightful",
            "Some great desserts",
            "What is the best dessert?",
          ],
        }
      end

      it "opens a menu with title suggestions" do
        open_move_topic_modal
        DiscourseAi::Completions::Llm.with_prepared_responses([titles]) do
          suggestion_menu.click_suggest_titles_button
          wait_for { suggestion_menu.has_dropdown? }
          expect(suggestion_menu).to have_dropdown
        end
      end

      it "replaces the title input with the selected title" do
        open_move_topic_modal
        DiscourseAi::Completions::Llm.with_prepared_responses([titles]) do
          suggestion_menu.click_suggest_titles_button
          wait_for { suggestion_menu.has_dropdown? }
          suggestion_menu.select_suggestion_by_value(1)

          expect(page).to have_field("split-topic-name", with: "Cake is the best!")
        end
      end
    end

    context "when suggesting categories with AI category suggester" do
      before do
        SiteSetting.ai_embeddings_selected_model = embedding_definition.id
        SiteSetting.ai_embeddings_enabled = true
      end

      it "updates the category with the suggested category" do
        response =
          Category
            .take(3)
            .pluck(:id, :name)
            .map { |s| { id: s[0], name: s[1], score: rand(0.0...45.0) } }
            .sort { |h| h[:score] }
        DiscourseAi::AiHelper::SemanticCategorizer.any_instance.stubs(:categories).returns(response)

        open_move_topic_modal
        suggestion_menu.click_suggest_category_button
        wait_for { suggestion_menu.has_dropdown? }
        suggestion = category.name
        suggestion_menu.select_suggestion_by_name(suggestion)
        category_selector = page.find(".category-chooser summary")

        expect(category_selector["data-name"]).to eq(suggestion)
      end
    end

    context "when suggesting tags with AI tag suggester" do
      before do
        SiteSetting.ai_embeddings_selected_model = embedding_definition.id
        SiteSetting.ai_embeddings_enabled = true
      end

      it "update the tag with the suggested tag" do
        response =
          Tag
            .take(5)
            .pluck(:name)
            .map { |s| { name: s, score: rand(0.0...45.0) } }
            .sort { |h| h[:score] }
        DiscourseAi::AiHelper::SemanticCategorizer.any_instance.stubs(:tags).returns(response)

        open_move_topic_modal
        suggestion_menu.click_suggest_tags_button
        wait_for { suggestion_menu.has_dropdown? }
        suggestion = suggestion_menu.suggestion_name(0)
        suggestion_menu.select_suggestion_by_value(0)

        expect(page).to have_css(".tag-chooser summary[data-name='#{suggestion}']")
      end
    end
  end
end
