# frozen_string_literal: true

require "seed_data/topics"

RSpec.describe SeedData::Topics do
  subject(:seeder) { SeedData::Topics.with_default_locale }

  before do
    general_category = Fabricate(:category, name: "General")
    SiteSetting.general_category_id = general_category.id
  end

  def create_topic(name = "welcome_topic_id")
    seeder.create(site_setting_names: [name], include_legal_topics: true)
  end

  describe "#create" do
    it "creates a missing topic" do
      staff_category = Fabricate(:category, name: "Feedback")
      SiteSetting.meta_category_id = staff_category.id

      expect { create_topic }.to change { Topic.count }.by(1).and change { Post.count }.by(1)

      topic = Topic.last
      expect(topic.title).to eq(
        I18n.t("discourse_welcome_topic.title", site_title: SiteSetting.title),
      )
      expect(topic.first_post.raw).to eq(
        I18n.t(
          "discourse_welcome_topic.body",
          base_path: Discourse.base_path,
          site_title: SiteSetting.title,
          site_description: SiteSetting.site_description,
          site_info_quote: "",
          feedback_category: "#feedback",
        ).rstrip,
      )
      expect(topic.category_id).to eq(SiteSetting.general_category_id)
      expect(topic.user_id).to eq(Discourse::SYSTEM_USER_ID)
      expect(topic.pinned_globally).to eq(true)
      expect(topic.pinned_at).to be_present
      expect(topic.pinned_until).to be_nil
      expect(SiteSetting.welcome_topic_id).to eq(topic.id)
    end

    it "creates a missing topic and a reply when `static_first_reply` is true" do
      staff_category = Fabricate(:category, name: "Staff")
      SiteSetting.staff_category_id = staff_category.id

      expect { create_topic("privacy_topic_id") }.to change { Topic.count }.by(1).and change {
              Post.count
            }.by(2)

      topic = Topic.last
      expect(topic.category_id).to eq(SiteSetting.staff_category_id)
      expect(topic.posts_count).to eq(2)
      expect(topic.pinned_globally).to eq(false)
      expect(topic.pinned_at).to be_nil
      expect(topic.pinned_until).to be_nil

      post = Post.last
      expect(post.topic_id).to eq(topic.id)
      expect(post.user_id).to eq(Discourse::SYSTEM_USER_ID)
      expect(post.raw).to eq(I18n.t("static_topic_first_reply", page_name: topic.title).rstrip)
    end

    it "does not create a topic when it already exists" do
      topic = Fabricate(:topic)
      SiteSetting.welcome_topic_id = topic.id

      expect { create_topic }.to_not change { Topic.count }
    end

    it "does not create a topic when the site setting points to non-existent topic" do
      SiteSetting.welcome_topic_id = (Topic.maximum(:id) || 0) + 1

      expect { create_topic }.to_not change { Topic.count }
    end

    it "does not create a legal topic if company_name is not set" do
      seeder.create(site_setting_names: ["tos_topic_id"])

      expect(SiteSetting.tos_topic_id).to eq(-1)
    end

    it "creates a welcome topic without site title" do
      SiteSetting.title = "My Awesome Community"
      SiteSetting.site_description = ""

      create_topic

      post = Post.find_by(topic_id: SiteSetting.welcome_topic_id, post_number: 1)
      expect(post.raw).not_to include("> ## My Awesome Community")
    end

    it "doesn't create a welcome topic when the 'General' category is missing" do
      SiteSetting.general_category_id = nil

      create_topic("welcome_topic_id")

      expect(SiteSetting.welcome_topic_id).to eq(-1)
    end

    it "creates a welcome topic with site title and description" do
      SiteSetting.title = "My Awesome Community"
      SiteSetting.site_description = "The best community"

      create_topic

      post = Post.find_by(topic_id: SiteSetting.welcome_topic_id, post_number: 1)
      expect(post.raw).to include("> ## My Awesome Community")
      expect(post.raw).to include("> The best community")
    end

    it "creates a legal topic if company_name is set" do
      SiteSetting.company_name = "Company Name"
      seeder.create(site_setting_names: ["tos_topic_id"])

      expect(SiteSetting.tos_topic_id).to_not eq(-1)
    end

    it "creates FAQ topic" do
      meta_category = Fabricate(:category, name: "Meta")
      staff_category = Fabricate(:category, name: "Feedback")
      SiteSetting.meta_category_id = meta_category.id
      SiteSetting.staff_category_id = staff_category.id
      create_topic("guidelines_topic_id")
      topic = Topic.find(SiteSetting.guidelines_topic_id)
      post = Post.find_by(topic_id: SiteSetting.guidelines_topic_id, post_number: 1)
      expect(topic.title).to_not include("Translation missing")
      expect(post.raw).to_not include("Translation missing")
    end
  end

  describe "#update" do
    def update_topic(name = "welcome_topic_id", skip_changed: false)
      seeder.update(site_setting_names: [name], skip_changed: skip_changed)
    end

    it "updates the changed topic" do
      create_topic

      topic = Topic.last
      topic.update!(title: "New topic title")
      topic.first_post.revise(Discourse.system_user, raw: "New text of first post.")

      update_topic
      topic.reload

      expect(topic.title).to eq(
        I18n.t("discourse_welcome_topic.title", site_title: SiteSetting.title),
      )
      expect(topic.first_post.raw).to eq(
        I18n.t(
          "discourse_welcome_topic.body",
          base_path: Discourse.base_path,
          site_title: SiteSetting.title,
          site_description: SiteSetting.site_description,
          site_info_quote: "",
          feedback_category: "#site-feedback",
        ).rstrip,
      )
    end

    it "updates an existing first reply when `static_first_reply` is true" do
      create_topic("privacy_topic_id")

      post = Post.last
      post.revise(Discourse.system_user, raw: "New text of first reply.")

      update_topic("privacy_topic_id")
      post.reload

      expect(post.raw).to eq(
        I18n.t("static_topic_first_reply", page_name: I18n.t("privacy_topic.title")).rstrip,
      )
    end

    it "does not update a change topic and `skip_changed` is true" do
      create_topic

      topic = Topic.last
      topic.update!(title: "New topic title")
      topic.first_post.revise(Fabricate(:admin), raw: "New text of first post.")

      update_topic(skip_changed: true)

      expect(topic.title).to eq("New topic title")
      expect(topic.first_post.raw).to eq("New text of first post.")
    end

    it "updates 'Welcome Topic' even when `general_category_id` doesn't exist" do
      create_topic("welcome_topic_id")
      SiteSetting.general_category_id = nil

      post = Post.last
      post.revise(Discourse.system_user, raw: "New text of first post.")

      update_topic
      post.reload

      expect(post.raw).to eq(
        I18n.t(
          "discourse_welcome_topic.body",
          base_path: Discourse.base_path,
          site_title: SiteSetting.title,
          site_description: SiteSetting.site_description,
          site_info_quote: "",
          feedback_category: "#site-feedback",
        ).rstrip,
      )
    end
  end

  describe "#delete" do
    def delete_topic(name = "welcome_topic_id", skip_changed: false)
      seeder.delete(site_setting_names: [name], skip_changed: skip_changed)
    end

    it "deletes the topic" do
      create_topic

      topic = Topic.last

      expect { delete_topic }.to change { Topic.count }.by(-1)
    end

    it "does not delete the topic if changed" do
      create_topic

      topic = Topic.last
      topic.first_post.revise(Fabricate(:admin), raw: "New text of first post.")

      expect { delete_topic(skip_changed: true) }.not_to change { Topic.count }
    end
  end

  describe "#reseed_options" do
    it "returns only existing topics as options" do
      create_topic("guidelines_topic_id")
      create_topic("welcome_topic_id")
      Post.last.revise(Fabricate(:admin), title: "Changed Topic Title", raw: "Hello world")

      expected_options = [
        { id: "guidelines_topic_id", name: I18n.t("guidelines_topic.title"), selected: true },
        { id: "welcome_topic_id", name: "Changed Topic Title", selected: false },
      ]

      expect(seeder.reseed_options).to eq(expected_options)
    end

    it "returns 'Welcome Topic' even when `general_category_id` doesn't exist" do
      create_topic("welcome_topic_id")
      SiteSetting.general_category_id = nil

      expected_options = [
        {
          id: "welcome_topic_id",
          name: I18n.t("discourse_welcome_topic.title", site_title: SiteSetting.title),
          selected: true,
        },
      ]

      expect(seeder.reseed_options).to eq(expected_options)
    end
  end
end
