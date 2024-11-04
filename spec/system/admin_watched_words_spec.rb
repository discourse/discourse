# frozen_string_literal: true

describe "Admin Watched Words", type: :system do
  fab!(:current_user) { Fabricate(:admin) }

  before { sign_in(current_user) }

  let(:ww_page) { PageObjects::Pages::AdminWatchedWords.new }

  it "correctly saves watched words" do
    ww_page.visit
    ww_page.add_word "foo"

    expect(ww_page).to have_word

    ww_page.visit

    expect(ww_page).to have_word
  end

  it "shows error when character limit is exceeded" do
    ww_page.visit
    ww_page.add_word "a" * 101

    expect(ww_page).to have_error("Word is too long (maximum is 100 characters)")
  end

  it "shows the 'outputs HTML' option when action=replace" do
    ww_page.visit
    expect(ww_page).not_to have_text(I18n.t("admin_js.admin.watched_words.form.html_description"))

    ww_page.visit(action: "replace")
    expect(ww_page).to have_text(I18n.t("admin_js.admin.watched_words.form.html_description"))
  end
end
