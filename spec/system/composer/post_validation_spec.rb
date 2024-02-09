# frozen_string_literal: true

describe "Composer Post Validations", type: :system do
  fab!(:tl0_user) { Fabricate(:user, trust_level: TrustLevel[0]) }
  fab!(:tl1_user) { Fabricate(:user, trust_level: TrustLevel[1]) }
  fab!(:tl2_user) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic: topic) }

  let(:composer) { PageObjects::Components::Composer.new }
  let(:topic_page) { PageObjects::Pages::Topic.new }

  shared_examples "post length validation" do
    context "when creating a topic" do
      it "shows an error when post length is insufficient" do
        visit("/latest")
        page.find("#create-topic").click
        composer.fill_content("abc")
        composer.create
        composer.have_post_error(I18n.t("js.composer.error.post_length"))
      end
    end

    context "when replying to a topic" do
      it "shows an error to like instead when post length is insufficient" do
        topic_page.visit_topic_and_open_composer(topic)
        composer.fill_content("abc")
        composer.create
        composer.have_post_error(
          "#{I18n.t("js.composer.error.post_length")} #{I18n.t("js.composer.error.try_like")}",
        )
      end
    end
  end

  describe "trust level 0 user" do
    before { sign_in(tl0_user) }
    include_examples "post length validation"
  end

  describe "trust level 1 user" do
    before { sign_in(tl1_user) }
    include_examples "post length validation"
  end

  describe "trust level 2 user" do
    before { sign_in(tl2_user) }

    context "when creating a topic" do
      it "shows an error when post length is insufficient" do
        visit("/latest")
        page.find("#create-topic").click
        composer.fill_content("abc")
        composer.create
        composer.have_post_error(I18n.t("js.composer.error.post_length"))
      end
    end

    context "when replying to a topic" do
      it "does not show an error to like when post length is insufficient" do
        topic_page.visit_topic_and_open_composer(topic)
        composer.fill_content("abc")
        composer.create
        composer.have_post_error("#{I18n.t("js.composer.error.post_length")}")
        composer.have_no_post_error(
          "#{I18n.t("js.composer.error.post_length")} #{I18n.t("js.composer.error.try_like")}",
        )
      end
    end
  end
end
