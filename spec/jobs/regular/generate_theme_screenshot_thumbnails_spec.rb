# frozen_string_literal: true

RSpec.describe Jobs::GenerateThemeScreenshotThumbnails do
  fab!(:upload, :image_upload)
  fab!(:theme) { Theme.horizon_theme }

  before do
    theme.set_field(
      target: :common,
      name: "screenshot_light",
      type: :theme_screenshot_upload_var,
      upload_id: upload.id,
    )
    theme.save!
  end

  it "raises when no theme is given" do
    expect { described_class.new.execute({}) }.to raise_error(Discourse::InvalidParameters)
  end

  it "does nothing for a theme that no longer exists" do
    expect { described_class.new.execute(theme_id: -99_999) }.not_to change { OptimizedImage.count }
  end

  it "resizes the theme's screenshots" do
    described_class.new.execute(theme_id: theme.id)

    expect(OptimizedImage.find_by(upload_id: upload.id)).to have_attributes(
      width: ThemeScreenshotThumbnails::WIDTH,
      height: ThemeScreenshotThumbnails::HEIGHT,
      extension: ".webp",
    )
  end

  it "reuses an already generated thumbnail" do
    described_class.new.execute(theme_id: theme.id)

    expect { described_class.new.execute(theme_id: theme.id) }.not_to change {
      OptimizedImage.count
    }
  end
end
