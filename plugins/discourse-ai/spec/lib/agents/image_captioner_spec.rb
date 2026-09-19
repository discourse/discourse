# frozen_string_literal: true

describe DiscourseAi::Agents::ImageCaptioner do
  it "enables image uploads by default" do
    expect(described_class.vision_enabled).to eq(true)
  end
end
