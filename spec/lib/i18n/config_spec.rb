# frozen_string_literal: true

RSpec.describe I18n::Config do
  it "does not leak an explicit locale into a new thread" do
    original_default_locale = I18n.default_locale
    original_locale = I18n.locale

    I18n.default_locale = :en
    I18n.locale = :zh_CN

    other_thread_locale = Thread.new { I18n.locale }.value

    expect(other_thread_locale).to eq(:en)
  ensure
    I18n.default_locale = original_default_locale
    I18n.locale = original_locale
  end
end
