# frozen_string_literal: true

describe "Admin Watched Words" do
  with_select_controls(false)

  fab!(:current_user, :admin)

  before { sign_in(current_user) }

  let(:ww_page) { PageObjects::Pages::AdminWatchedWords.new }

  shared_examples "adding watched words" do
    it "correctly saves watched words" do
      ww_page.visit
      ww_page.add_word "foo"

      expect(ww_page).to have_word

      ww_page.visit

      expect(ww_page).to have_word
    end

    it "shows the 'outputs HTML' option when action=replace" do
      ww_page.visit
      expect(ww_page).not_to have_text(I18n.t("admin_js.admin.watched_words.form.html_description"))

      ww_page.visit(action: "replace")
      expect(ww_page).to have_text(I18n.t("admin_js.admin.watched_words.form.html_description"))
    end

    it "creates a watched word with the tag action type" do
      Fabricate(:tag, name: "greeting")

      ww_page.visit(action: "tag")
      ww_page.add_word_with_tag("hello", "greeting")

      expect(ww_page).to have_word

      watched_word = WatchedWord.find_by(word: "hello")
      expect(watched_word).to be_present
      expect(watched_word.action).to eq(WatchedWord.actions[:tag])
      expect(watched_word.replacement).to eq("greeting")
    end
  end

  include_examples "adding watched words"

  it "shows error when character limit is exceeded" do
    ww_page.visit
    ww_page.add_word "a" * 101

    expect(ww_page).to have_error("Word is too long (maximum is 100 characters)")
  end

  context "with the new select controls" do
    with_select_controls(true)

    include_examples "adding watched words"

    it "doesn't offer a word past the character limit" do
      ww_page.visit
      words = PageObjects::Components::UiKit::DSelect.by_identifier("watched-words")
      words.search("a" * 101)

      expect(words).to have_no_option_name("a" * 101)
      expect(page).to have_text(I18n.t("admin_js.admin.watched_words.form.too_long", max: 100))
    end

    it "creates a watched word with the tag action type with the new select controls" do
      Fabricate(:tag, name: "greeting")

      ww_page.visit(action: "tag")

      expect(page).to have_css(".watched-word-input .tag-chooser.d-select")

      ww_page.add_word_with_tag("hello", "greeting")

      expect(ww_page).to have_word

      watched_word = WatchedWord.find_by(word: "hello")
      expect(watched_word).to be_present
      expect(watched_word.action).to eq(WatchedWord.actions[:tag])
      expect(watched_word.replacement).to eq("greeting")
    end

    it "creates a watched word with a new tag with the new select controls" do
      ww_page.visit(action: "tag")

      tag_chooser = PageObjects::Components::UiKit::DSelect.at(".watched-word-input .tag-chooser")
      ww_page.enter_word("hello")

      tag_chooser.search("brand-new")
      tag_chooser.select_name("brand-new")
      tag_chooser.close

      expect(tag_chooser).to have_selected_names("brand-new")

      find(".watched-words-detail .btn-primary").click

      expect(ww_page).to have_word
      expect(WatchedWord.find_by(word: "hello")&.replacement).to eq("brand-new")
    end
  end
end
