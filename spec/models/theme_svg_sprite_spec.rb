# frozen_string_literal: true

RSpec.describe ThemeSvgSprite do
  fab!(:theme)

  describe "#refetch!" do
    context "when an upload exists" do
      before do
        fname = "custom-theme-icon-sprite.svg"
        upload = UploadCreator.new(file_from_fixtures(fname), fname, for_theme: true).create_for(-1)

        theme.set_field(
          target: :common,
          name: SvgSprite.theme_sprite_variable_name,
          upload_id: upload.id,
          type: :theme_upload_var,
        )

        theme.save!
      end

      it "fetches values from the store and puts them in the table" do
        expect(ThemeSvgSprite.count).to eq(1)

        sprite = ThemeSvgSprite.first
        original_content = sprite.sprite

        expect(original_content).not_to be_empty

        sprite.update!(sprite: "INVALID")

        ThemeSvgSprite.refetch!

        sprite.reload
        expect(sprite.sprite).to eq(original_content)
        expect(ThemeSvgSprite.count).to eq(1)
      end
    end

    # It needs to do this since the cache is based on values in this table
    it "expires the svg sprite cache" do
      SvgSprite.expects(:expire_cache)

      ThemeSvgSprite.refetch!
    end
  end
end
