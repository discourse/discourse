# frozen_string_literal: true

RSpec.describe "Admin EmbeddableHost Management", type: :system do
  fab!(:admin)
  fab!(:author) { Fabricate(:admin) }
  fab!(:category)
  fab!(:category2) { Fabricate(:category) }
  fab!(:tag)
  fab!(:tag2) { Fabricate(:tag) }

  before { sign_in(admin) }

  it "allows admin to add and edit embeddable hosts" do
    visit "/admin/customize/embedding"

    find("button.btn-icon-text", text: "Add Host").click
    within find("tr.ember-view") do
      find('input[placeholder="example.com"]').set("awesome-discourse-site.local")
      find('input[placeholder="/blog/.*"]').set("/blog/.*")

      category_chooser = PageObjects::Components::SelectKit.new(".category-chooser")
      category_chooser.expand
      category_chooser.select_row_by_name(category.name)

      tag_chooser = PageObjects::Components::SelectKit.new(".tag-chooser")
      tag_chooser.expand
      tag_chooser.select_row_by_name(tag.name)

      find(".user-chooser").click
      find(".select-kit-body .select-kit-filter input").fill_in with: author.username
      find(".select-kit-body", text: author.username).click
    end
    find("td.editing-controls .btn.btn-primary").click
    expect(page).to have_content("awesome-discourse-site.local")
    expect(page).to have_content("/blog/.*")
    expect(page).not_to have_content("#{tag.name},#{tag2.name}")
    expect(page).to have_content("#{tag.name}")

    # Editing

    find(".embeddable-hosts tr:first-child .controls svg.d-icon-pencil-alt").find(
      :xpath,
      "..",
    ).click

    within find(".embeddable-hosts tr:first-child.ember-view") do
      find('input[placeholder="example.com"]').set("updated-example.com")
      find('input[placeholder="/blog/.*"]').set("/updated-blog/.*")

      category_chooser = PageObjects::Components::SelectKit.new(".category-chooser")
      category_chooser.expand
      category_chooser.select_row_by_name(category2.name)

      tag_chooser = PageObjects::Components::SelectKit.new(".tag-chooser")
      tag_chooser.expand
      tag_chooser.select_row_by_name(tag2.name)
    end

    find("td.editing-controls .btn.btn-primary").click
    expect(page).to have_content("updated-example.com")
    expect(page).to have_content("/updated-blog/.*")
    expect(page).to have_content("#{tag.name},#{tag2.name}")
  end
end
