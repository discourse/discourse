# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::Researcher do
  subject(:researcher) { described_class.new }

  before { enable_current_plugin }

  it "renders schema" do
    expect(researcher.tools).to eq(
      [DiscourseAi::Agents::Tools::Google, DiscourseAi::Agents::Tools::WebBrowser],
    )
  end
end
