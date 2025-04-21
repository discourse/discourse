# frozen_string_literal: true

RSpec.describe QunitController do
  def production_sign_in(user)
    # We need to call sign_in before stubbing the method because SessionController#become
    # checks for the current env when the file is loaded.
    # We need to make sure become is called once before stubbing, or the method
    # wont'be available for future tests if this one runs first.
    sign_in(user) if user
    Rails.env.stubs(:production?).returns(true)
  end

  # rubocop:disable RSpec/BeforeAfterAll
  before(:all) { DiscourseJsProcessor::Transpiler.build_production_theme_transpiler }

  after(:all) { File.delete(DiscourseJsProcessor::Transpiler::TRANSPILER_PATH) }

  it "hides page for regular users in production" do
    production_sign_in(Fabricate(:user))
    get "/theme-qunit"
    expect(response.status).to eq(404)
  end

  it "hides page for anon in production" do
    production_sign_in(nil)
    get "/theme-qunit"
    expect(response.status).to eq(404)
  end

  it "shows page for admin in production" do
    production_sign_in(Fabricate(:admin))
    get "/theme-qunit"
    expect(response.status).to eq(200)
  end
end
