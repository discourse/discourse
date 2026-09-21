# frozen_string_literal: true

RSpec.describe SvgSprite::FontAwesomeSync do
  subject(:sync) { described_class.new(package_path:, vendor_path:) }

  let(:package_path) { Pathname.new(Dir.mktmpdir) }
  let(:vendor_path) { Pathname.new(Dir.mktmpdir) }

  after { FileUtils.rm_rf([package_path, vendor_path]) }

  def sprite(artwork)
    symbols = artwork.map { |id, path| <<~XML }.join
        <symbol id="#{id}" viewBox="0 0 512 512">
        <path fill="currentColor" d="#{path}"/>
        </symbol>
      XML

    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <svg xmlns="http://www.w3.org/2000/svg" style="display: none;">
      #{symbols}</svg>
    XML
  end

  def publish_package(solid:, aliases: {})
    package_path.join("sprites").mkpath
    package_path.join("metadata").mkpath

    package_path.join("sprites/solid.svg").write(sprite(solid))
    package_path.join("sprites/regular.svg").write(sprite({}))
    package_path.join("sprites/brands.svg").write(sprite({}))

    metadata = aliases.to_h { |id, names| [id, { "aliases" => { "names" => names } }] }
    package_path.join("metadata/icon-families.json").write(metadata.to_json)
  end

  def vendor_solid(artwork)
    vendor_path.join("fontawesome").mkpath
    vendor_path.join("fontawesome/solid.svg").write(sprite(artwork))
  end

  def legacy_solid_artwork
    Nokogiri
      .XML(vendor_path.join("fontawesome-legacy/solid.svg").read)
      .remove_namespaces!
      .css("symbol")
      .to_h { |symbol| [symbol["id"], symbol.at_css("path")["d"]] }
  end

  describe "#write!" do
    it "vendors the package sprites unchanged" do
      publish_package(solid: { "heart" => "M1" })

      sync.write!

      expect(vendor_path.join("fontawesome/solid.svg").read).to eq(
        package_path.join("sprites/solid.svg").read,
      )
      expect(vendor_path.join("fontawesome-legacy")).not_to exist
    end

    it "keeps renamed icons under their old name with the successor's artwork" do
      vendor_solid("user-large" => "M-old")
      publish_package(solid: { "user" => "M-new" }, aliases: { "user" => ["user-large"] })

      sync.write!

      expect(legacy_solid_artwork).to eq("user-large" => "M-new")
    end

    it "keeps removed icons with their previously vendored artwork" do
      vendor_solid("vector-square" => "M-old")
      publish_package(solid: { "heart" => "M1" })

      sync.write!

      expect(legacy_solid_artwork).to eq("vector-square" => "M-old")
    end

    it "carries legacy icons into later syncs and refreshes renamed artwork" do
      vendor_solid("user-large" => "M-old", "vector-square" => "M-old")
      publish_package(solid: { "user" => "M-new" }, aliases: { "user" => ["user-large"] })
      sync.write!

      publish_package(solid: { "user" => "M-newer" }, aliases: { "user" => ["user-large"] })
      described_class.new(package_path:, vendor_path:).write!

      expect(legacy_solid_artwork).to eq("user-large" => "M-newer", "vector-square" => "M-old")
    end

    it "removes the legacy sprite once the package ships its icons again" do
      vendor_solid("vector-square" => "M-old")
      publish_package(solid: { "heart" => "M1" })
      sync.write!

      publish_package(solid: { "heart" => "M1", "vector-square" => "M-new" })
      described_class.new(package_path:, vendor_path:).write!

      expect(vendor_path.join("fontawesome-legacy/solid.svg")).not_to exist
    end

    it "refuses package sprites with markup beyond plain path artwork" do
      publish_package(solid: { "heart" => "M1" })
      package_path.join("sprites/solid.svg").write(<<~XML)
        <svg xmlns="http://www.w3.org/2000/svg" style="display: none;">
        <symbol id="heart" viewBox="0 0 512 512"><image href="x" onerror="alert(1)"/></symbol>
        </svg>
      XML

      expect { sync.write! }.to raise_error(described_class::UnsafeSpriteError, /heart/)
      expect(vendor_path.join("fontawesome/solid.svg")).not_to exist
    end
  end

  describe "#stale_files" do
    it "lists vendored files that differ from the package until they are written" do
      vendor_solid("vector-square" => "M-old")
      publish_package(solid: { "heart" => "M1" })

      expect(sync.stale_files).to contain_exactly(
        vendor_path.join("fontawesome/solid.svg"),
        vendor_path.join("fontawesome/regular.svg"),
        vendor_path.join("fontawesome/brands.svg"),
        vendor_path.join("fontawesome-legacy/solid.svg"),
      )

      sync.write!

      expect(described_class.new(package_path:, vendor_path:).stale_files).to be_empty
    end
  end
end
