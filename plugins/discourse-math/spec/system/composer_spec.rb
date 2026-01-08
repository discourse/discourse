# frozen_string_literal: true

RSpec.describe "Discourse Math - composer", type: :system do
  fab!(:current_user) do
    # Start in markdown mode so we can type math syntax, then toggle to rich editor
    Fabricate(:admin, composition_mode: UserOption.composition_mode_types[:markdown])
  end
  fab!(:category)

  let(:composer) { PageObjects::Components::Composer.new }
  let(:rich) { composer.rich_editor }

  before do
    SiteSetting.discourse_math_enabled = true
    SiteSetting.rich_editor = true
    sign_in(current_user)
  end

  def open_composer_and_type_math(math_content)
    visit("/new-topic")
    expect(composer).to be_opened
    composer.fill_title("Math test topic")
    # Type math in markdown mode
    composer.fill_content(math_content)
    # Toggle to rich editor to trigger math parsing and rendering
    composer.toggle_rich_editor
    expect(composer).to have_rich_editor_active
  end

  describe "MathJax provider" do
    before { SiteSetting.discourse_math_provider = "mathjax" }

    it "renders inline math in rich editor" do
      open_composer_and_type_math("Inline math: $E=mc^2$ here")

      expect(rich).to have_css(".composer-math-node .math-container mjx-container", wait: 10)
    end

    it "renders block math in rich editor" do
      open_composer_and_type_math("Block math:\n\n$$\nx^2 + y^2 = z^2\n$$")

      expect(rich).to have_css(".composer-math-node .math-container mjx-container", wait: 10)
    end
  end

  describe "KaTeX provider" do
    before { SiteSetting.discourse_math_provider = "katex" }

    it "renders inline math in rich editor" do
      open_composer_and_type_math("Inline math: $E=mc^2$ here")

      expect(rich).to have_css(".composer-math-node .math-container .katex", wait: 10)
    end
  end
end
