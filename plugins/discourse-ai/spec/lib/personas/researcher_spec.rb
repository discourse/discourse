# frozen_string_literal: true

RSpec.describe DiscourseAi::Personas::Researcher do
  subject(:researcher) { described_class.new }

  before { enable_current_plugin }

  it "renders schema" do
    expect(researcher.tools).to eq(
      [DiscourseAi::Personas::Tools::Google, DiscourseAi::Personas::Tools::WebBrowser],
    )
  end
end
