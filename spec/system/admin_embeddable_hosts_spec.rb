# frozen_string_literal: true

RSpec.describe "Admin EmbeddableHost Management", type: :system do
  fab!(:admin)
  fab!(:author) { Fabricate(:admin) }
  fab!(:author_2) { Fabricate(:admin) }
  fab!(:category)
  fab!(:category_2) { Fabricate(:category) }
  fab!(:tag)
  fab!(:tag_2) { Fabricate(:tag) }

  before { sign_in(admin) }

  let(:admin_embedding_page) { PageObjects::Pages::AdminEmbedding.new }
  let(:admin_embedding_host_form_page) { PageObjects::Pages::AdminEmbeddingHostForm.new }
  let(:admin_embedding_posts_and_topics_page) do
    PageObjects::Pages::AdminEmbeddingPostsAndTopics.new
  end

  it "allows admin to add, edit and delete embeddable hosts" do
    admin_embedding_page.visit

    expect(page).not_to have_css(".admin-embedding-index__code")

    admin_embedding_page.click_add_host

    admin_embedding_host_form_page.fill_in_allowed_hosts("awesome-discourse-site.local")
    admin_embedding_host_form_page.fill_in_path_allow_list("/blog/.*")
    admin_embedding_host_form_page.fill_in_category(category)
    admin_embedding_host_form_page.fill_in_tags(tag)
    admin_embedding_host_form_page.fill_in_post_author(author)
    admin_embedding_host_form_page.click_save

    expect(page).to have_content("awesome-discourse-site.local")
    expect(page).to have_content("/blog/.*")
    expect(page).to have_content("#{tag.name}")
    expect(page).to have_content("#{category.name}")
    expect(page).to have_content("#{author.username}")

    expect(page).to have_css(".admin-embedding-index__code")

    admin_embedding_page.click_edit_host

    admin_embedding_host_form_page.fill_in_allowed_hosts("updated-example.com")
    admin_embedding_host_form_page.fill_in_path_allow_list("/updated-blog/.*")
    admin_embedding_host_form_page.fill_in_category(category_2)
    admin_embedding_host_form_page.fill_in_tags(tag_2)
    admin_embedding_host_form_page.fill_in_post_author(author_2)
    admin_embedding_host_form_page.click_save

    expect(page).to have_content("updated-example.com")
    expect(page).to have_content("/updated-blog/.*")
    expect(page).to have_content("#{tag.name}, #{tag_2.name}")
    expect(page).to have_content("#{category_2.name}")
    expect(page).to have_content("#{author_2.username}")

    admin_embedding_page.click_delete
    admin_embedding_page.confirm_delete

    expect(page).not_to have_css(".admin-embedding-index__code")
  end

  it "allows admin to save posts and topics settings" do
    Fabricate(:embeddable_host)

    admin_embedding_page.visit
    expect(page).not_to have_content("#{author.username}")

    admin_embedding_page.click_posts_and_topics_tab

    admin_embedding_posts_and_topics_page.fill_in_embed_by_username(author)
    admin_embedding_posts_and_topics_page.click_save

    admin_embedding_page.click_hosts_tab
    expect(page).to have_content("#{author.username}")
  end
end
