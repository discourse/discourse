# frozen_string_literal: true

describe "Edit AI post image descriptions" do
  fab!(:admin)
  fab!(:first_cat_upload) { create_image_upload("100x100.jpg", "first-cat.jpg") }
  fab!(:second_cat_upload) do
    create_image_upload("An image of discobot in action.png", "second-cat.png")
  end
  fab!(:dog_upload) { create_image_upload("1x1.jpg", "dog.jpg") }

  fab!(:cat_topic) { Fabricate(:topic, title: "A topic about cats", user: admin, locale: "en") }
  fab!(:other_topic) { Fabricate(:topic, title: "A topic about dogs", user: admin, locale: "en") }

  fab!(:first_post) do
    Fabricate(
      :post,
      topic: cat_topic,
      user: admin,
      post_number: 1,
      locale: "en",
      raw: "No image in this post",
    )
  end

  fab!(:second_post) do
    Fabricate(
      :post,
      topic: cat_topic,
      user: admin,
      post_number: 2,
      locale: "en",
      raw:
        "Two cats here\n\n" \
          "![first cat|200x200](#{first_cat_upload.short_url})\n\n" \
          "![second cat|200x200](#{second_cat_upload.short_url})",
    )
  end

  fab!(:third_post) do
    Fabricate(
      :post,
      topic: cat_topic,
      user: admin,
      post_number: 3,
      locale: "en",
      raw: "The same second cat\n\n![second cat again|200x200](#{second_cat_upload.short_url})",
    )
  end

  fab!(:other_post) do
    Fabricate(
      :post,
      topic: other_topic,
      user: admin,
      locale: "en",
      raw: "A dog post\n\n![dog|200x200](#{dog_upload.short_url})",
    )
  end

  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:composer) { PageObjects::Components::Composer.new }
  let(:captions) { PageObjects::Components::AiPostImageDescriptions.new }

  let(:first_cat_caption) { "An old caption for the first cat" }
  let(:second_cat_caption) { "An old caption for the shared second cat" }
  let(:dog_caption) { "An old caption for the dog" }
  let(:edited_second_cat_caption) { "An edited caption for only the second post cat" }
  let(:japanese_first_cat_caption) { "一匹目の猫の古い説明" }
  let(:japanese_second_cat_caption) { "共有された二匹目の猫の古い説明" }

  around { |example| Jobs.with_immediate_jobs { example.run } }

  before do
    enable_current_plugin
    SiteSetting.default_locale = "en"
    SiteSetting.ai_post_image_descriptions_enabled = true
    SearchIndexer.enable

    prepare_post(first_post)
    prepare_post(second_post, image_upload: first_cat_upload)
    prepare_post(third_post, image_upload: second_cat_upload)
    prepare_post(other_post, image_upload: dog_upload)
  end

  after { SearchIndexer.disable }

  it "lets the user edit one reused cat caption", :aggregate_failures do
    SiteSetting.content_localization_enabled = false
    seed_english_descriptions

    sign_in(admin)
    topic_page.visit_topic(cat_topic)

    expect(captions).to have_post_image_count(first_post, count: 0)
    expect(captions).to have_post_image_count(second_post, count: 2)
    expect(captions).to have_post_image_count(third_post, count: 1)
    expect(captions).to have_image_description(
      second_post,
      image: 2,
      description: second_cat_caption,
    )
    expect(captions).to have_image_description(
      third_post,
      image: 1,
      description: second_cat_caption,
    )

    topic_page.expand_post_actions(second_post)
    topic_page.click_post_action_button(second_post, :edit)
    expect(composer).to be_opened
    expect(captions).to have_editor_button_count(count: 2)

    captions.edit_preview_image_description(image: 2, description: edited_second_cat_caption)
    process_description_cooked(post_id: second_post.id, locale: "en")
    composer.close
    expect(composer).to be_closed

    topic_page.visit_topic(cat_topic)

    expect(captions).to have_image_description(
      second_post,
      image: 2,
      description: edited_second_cat_caption,
    )
    expect(captions).to have_image_description(
      third_post,
      image: 1,
      description: second_cat_caption,
    )
  end

  it "shows locale-specific captions and original-locale fallback", :aggregate_failures do
    SiteSetting.allow_user_locale = true
    SiteSetting.content_localization_enabled = true
    SiteSetting.content_localization_allowed_groups = Group::AUTO_GROUPS[:admins]
    SiteSetting.content_localization_supported_locales = "en|ja"
    admin.update!(locale: "ja")
    admin.user_option.update!(show_original_content: false)
    Fabricate(:topic_localization, topic: cat_topic, locale: "ja", fancy_title: "猫についての話題")
    create_japanese_localization(second_post)
    seed_english_descriptions
    seed_image_description(second_post, first_cat_upload, japanese_first_cat_caption, locale: "ja")
    seed_image_description(
      second_post,
      second_cat_upload,
      japanese_second_cat_caption,
      locale: "ja",
    )
    process_description_cooked(post_id: second_post.id, locale: "ja")

    sign_in(admin)
    topic_page.visit_topic(cat_topic)

    expect(captions).to have_image_description(
      second_post,
      image: 2,
      description: japanese_second_cat_caption,
    )

    admin.user_option.update!(show_original_content: true)
    topic_page.visit_topic(cat_topic)

    expect(captions).to have_image_description(
      second_post,
      image: 2,
      description: second_cat_caption,
    )
  end

  def create_image_upload(filename, original_filename)
    UploadCreator.new(
      file_from_fixtures(
        filename,
        "images",
        Rails.root.join("plugins/discourse-ai/spec/fixtures").to_s,
      ),
      original_filename,
    ).create_for(Discourse.system_user.id)
  end

  def prepare_post(post, image_upload: nil)
    post.update_column(:cooked, post.cook(post.raw, topic_id: post.topic_id))
    post.link_post_uploads
    post.update_column(:image_upload_id, image_upload.id) if image_upload
  end

  def seed_english_descriptions
    seed_image_description(second_post, first_cat_upload, first_cat_caption)
    seed_image_description(second_post, second_cat_upload, second_cat_caption)
    seed_image_description(third_post, second_cat_upload, second_cat_caption)
    seed_image_description(other_post, dog_upload, dog_caption)

    process_description_cooked(post_id: second_post.id, locale: "en")
    process_description_cooked(post_id: third_post.id, locale: "en")
    process_description_cooked(post_id: other_post.id, locale: "en")
  end

  def seed_image_description(post, upload, description, locale: "en")
    AiPostImageDescription.create!(
      post_id: post.id,
      upload_id: upload.id,
      base62_sha1: upload.base62_sha1,
      locale: locale,
      description: description,
      attempts: 0,
    )
  end

  def create_japanese_localization(post)
    raw =
      "翻訳された猫の投稿\n\n" \
        "![一匹目の猫|200x200](#{first_cat_upload.short_url})\n\n" \
        "![二匹目の猫|200x200](#{second_cat_upload.short_url})"

    Fabricate(
      :post_localization,
      post: post,
      locale: "ja",
      raw: raw,
      cooked: post.cook(raw, topic_id: post.topic_id),
    )
  end

  def process_description_cooked(post_id:, locale:)
    post = Post.find(post_id)
    locale = locale.presence || DiscourseAi::PostImageDescriptions.original_locale(post)

    if locale == DiscourseAi::PostImageDescriptions.original_locale(post)
      Jobs::ProcessPost.new.execute(post_id: post.id, bypass_bump: true)
    else
      PostLocalization
        .where(post_id: post.id, locale: locale)
        .pluck(:id)
        .each do |post_localization_id|
          Jobs::ProcessLocalizedCooked.new.execute(
            post_localization_id: post_localization_id,
            recook: true,
          )
        end
    end
  end
end
