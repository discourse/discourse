# frozen_string_literal: true

describe "Async StyleSheets", type: :system do
  it "should display the Ember app when `async_stylesheets` param is `true`" do
    visit("/?async_stylesheets=true")

    expect(page).to have_css(".ember-application", visible: true)
    expect(page).to have_css("link.async-css-loading.light-scheme[media=\"all\"]", visible: false)
  end
end
