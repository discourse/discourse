# frozen_string_literal: true

describe AdPlugin::HouseAd do
  let(:valid_attrs) do
    {
      name: "Find A Mechanic",
      html:
        '<div class="house-ad find-a-mechanic"><a href="https://mechanics.example.com">Find A Mechanic!</a></div>',
    }
  end

  before { enable_current_plugin }

  describe ".find" do
    let!(:ad) { AdPlugin::HouseAd.create(valid_attrs) }

    it "raises RecordNotFound if no match" do
      expect { AdPlugin::HouseAd.find(100) }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "can retrieve by id" do
      r = AdPlugin::HouseAd.find(ad.id)
      expect(r&.name).to eq(valid_attrs[:name])
      expect(r&.html).to eq(valid_attrs[:html])
    end
  end

  describe ".all" do
    it "returns empty array if no records" do
      expect(AdPlugin::HouseAd.all).to eq([])
    end

    it "returns an array of records" do
      AdPlugin::HouseAd.create(valid_attrs)
      AdPlugin::HouseAd.create(valid_attrs.merge(name: "Ad 2", html: "<div>Ad 2 Here</div>"))
      all = AdPlugin::HouseAd.all
      expect(all.size).to eq(2)
      expect(all.map(&:name)).to contain_exactly("Ad 2", valid_attrs[:name])
      expect(all.map(&:html)).to contain_exactly("<div>Ad 2 Here</div>", valid_attrs[:html])
    end
  end

  describe ".all_for_anons" do
    fab!(:anon_ad) do
      Fabricate(:house_ad, visible_to_logged_in_users: false, visible_to_anons: true)
    end
    fab!(:logged_in_ad) do
      Fabricate(:house_ad, visible_to_logged_in_users: true, visible_to_anons: false)
    end

    it "doesn't include ads for logged in users" do
      expect(AdPlugin::HouseAd.all_for_anons.map(&:id)).to contain_exactly(anon_ad.id)
    end
  end

  describe ".all_for_logged_in_users" do
    fab!(:anon_ad) do
      Fabricate(:house_ad, visible_to_logged_in_users: false, visible_to_anons: true)
    end
    fab!(:logged_in_ad) do
      Fabricate(:house_ad, visible_to_logged_in_users: true, visible_to_anons: false)
    end
    fab!(:user)

    it "doesn't include ads for anonymous users" do
      expect(
        AdPlugin::HouseAd.all_for_logged_in_users(Guardian.new(user)).map(&:id),
      ).to contain_exactly(logged_in_ad.id)
    end
  end

  describe "#save" do
    it "assigns an id and attrs for new record" do
      ad = AdPlugin::HouseAd.new(valid_attrs)
      expect(ad.save).to eq(true)
      expect(ad.name).to eq(valid_attrs[:name])
      expect(ad.html).to eq(valid_attrs[:html])
      expect(ad.id.to_i > 0).to eq(true)
      ad2 = AdPlugin::HouseAd.new(valid_attrs.merge(name: "Find Another Mechanic"))
      expect(ad2.save).to eq(true)
      expect(ad2.id).to_not eq(ad.id)
    end

    it "updates existing record" do
      ad = AdPlugin::HouseAd.create(valid_attrs)
      id = ad.id
      ad.name = "Sell Your Car"
      ad.html = '<div class="house-ad">Sell Your Car!</div>'
      expect(ad.save).to eq(true)
      ad = AdPlugin::HouseAd.find(id)
      expect(ad.name).to eq("Sell Your Car")
      expect(ad.html).to eq('<div class="house-ad">Sell Your Car!</div>')
      expect(ad).to be_valid
    end

    describe "errors" do
      it "blank name" do
        ad = AdPlugin::HouseAd.new(valid_attrs.merge(name: ""))
        expect(ad.save).to eq(false)
        expect(ad).to_not be_valid
        expect(ad.errors.full_messages).to be_present
        expect(ad.errors[:name]).to be_present
        expect(ad.errors.count).to eq(1)
      end

      it "duplicate name" do
        AdPlugin::HouseAd.create(valid_attrs)
        ad = AdPlugin::HouseAd.new(valid_attrs)
        expect(ad.save).to eq(false)
        expect(ad).to_not be_valid
        expect(ad.errors.full_messages).to be_present
        expect(ad.errors[:name]).to be_present
        expect(ad.errors.count).to eq(1)
      end

      it "duplicate name, different case" do
        AdPlugin::HouseAd.create(valid_attrs.merge(name: "mechanic"))
        ad = AdPlugin::HouseAd.create(valid_attrs.merge(name: "mechanic"))

        expect(ad.save).to eq(false)
        expect(ad).to_not be_valid
        expect(ad.errors[:name]).to be_present
        expect(ad.errors.count).to eq(1)
      end

      it "blank html" do
        ad = AdPlugin::HouseAd.new(valid_attrs.merge(html: ""))
        expect(ad.save).to eq(false)
        expect(ad).to_not be_valid
        expect(ad.errors.full_messages).to be_present
        expect(ad.errors[:html]).to be_present
        expect(ad.errors.count).to eq(1)
      end

      it "invalid name" do
        ad = AdPlugin::HouseAd.new(valid_attrs.merge(name: "<script>"))
        expect(ad.save).to eq(false)
        expect(ad).to_not be_valid
        expect(ad.errors[:name]).to be_present
        expect(ad.errors.count).to eq(1)
      end
    end
  end

  describe ".create" do
    it "can create new records" do
      ad = AdPlugin::HouseAd.create(valid_attrs)
      expect(ad).to be_a(AdPlugin::HouseAd)
      expect(ad.id).to be_present
      expect(ad.name).to eq(valid_attrs[:name])
      expect(ad.html).to eq(valid_attrs[:html])
    end

    it "validates attributes" do
      ad = AdPlugin::HouseAd.create(name: "", html: "")
      expect(ad).to be_a(AdPlugin::HouseAd)
      expect(ad).to_not be_valid
      expect(ad.errors.full_messages).to be_present
      expect(ad.errors.count).to eq(2)
    end
  end

  describe "#destroy" do
    it "can delete a record" do
      ad = AdPlugin::HouseAd.create(valid_attrs)
      ad.destroy
      expect { AdPlugin::HouseAd.find(ad.id) }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "#update" do
    let(:ad) { AdPlugin::HouseAd.create(valid_attrs) }

    it "updates existing record" do
      expect(
        ad.update(
          name: "Mechanics 4 Hire",
          html: '<a href="https://mechanics.example.com">Find A Mechanic!</a>',
        ),
      ).to eq(true)
      after_save = AdPlugin::HouseAd.find(ad.id)
      expect(after_save.name).to eq("Mechanics 4 Hire")
      expect(after_save.html).to eq('<a href="https://mechanics.example.com">Find A Mechanic!</a>')
    end

    it "validates attributes" do
      expect(ad.update(name: "", html: "")).to eq(false)
      expect(ad).to_not be_valid
      expect(ad.errors.full_messages).to be_present
      expect(ad.errors.count).to eq(2)
    end
  end

  describe "sanitize_html" do
    it "removes script tags" do
      ad =
        AdPlugin::HouseAd.create!(
          valid_attrs.merge(html: "<div>Hello</div><script>alert(1)</script>"),
        )
      expect(ad.html).to eq("<div>Hello</div>")
    end

    it "removes noscript tags" do
      ad =
        AdPlugin::HouseAd.create!(
          valid_attrs.merge(html: '<div>Hello</div><noscript><img src="x"></noscript>'),
        )
      expect(ad.html).to eq("<div>Hello</div>")
    end

    it "removes base tags" do
      ad =
        AdPlugin::HouseAd.create!(
          valid_attrs.merge(html: '<base href="https://evil.com"><div>Hello</div>'),
        )
      expect(ad.html).to eq("<div>Hello</div>")
    end

    it "removes on* event handler attributes" do
      ad =
        AdPlugin::HouseAd.create!(
          valid_attrs.merge(
            html:
              '<img src="x.png" onerror="alert(1)"><a onclick="alert(1)" href="https://example.com">Click</a>',
          ),
        )
      expect(ad.html).not_to include("onerror")
      expect(ad.html).not_to include("onclick")
      expect(ad.html).to include('href="https://example.com"')
      expect(ad.html).to include('src="x.png"')
    end

    it "removes javascript: protocol in href" do
      ad =
        AdPlugin::HouseAd.create!(
          valid_attrs.merge(html: '<a href="javascript:alert(1)">Click</a>'),
        )
      expect(ad.html).not_to include("javascript:")
    end

    it "removes javascript: protocol with mixed case" do
      ad =
        AdPlugin::HouseAd.create!(
          valid_attrs.merge(html: '<a href="JaVaScRiPt:alert(1)">Click</a>'),
        )
      expect(ad.html).not_to include("JaVaScRiPt:")
    end

    it "removes javascript: protocol with control character evasion" do
      ad =
        AdPlugin::HouseAd.create!(
          valid_attrs.merge(html: "<a href=\"java\tscript:alert(1)\">Click</a>"),
        )
      expect(ad.html).not_to include("javascript:")
    end

    it "removes javascript: protocol in src attributes" do
      ad =
        AdPlugin::HouseAd.create!(
          valid_attrs.merge(html: '<iframe src="javascript:alert(1)"></iframe>'),
        )
      expect(ad.html).not_to include("javascript:")
    end

    it "preserves id attributes" do
      ad = AdPlugin::HouseAd.create!(valid_attrs.merge(html: '<div id="my-ad">Hello</div>'))
      expect(ad.html).to include('id="my-ad"')
    end

    it "preserves data-* attributes" do
      ad =
        AdPlugin::HouseAd.create!(
          valid_attrs.merge(html: '<div data-campaign="spring">Hello</div>'),
        )
      expect(ad.html).to include('data-campaign="spring"')
    end

    it "preserves style attributes" do
      ad = AdPlugin::HouseAd.create!(valid_attrs.merge(html: '<div style="color: red">Hello</div>'))
      expect(ad.html).to include('style="color: red"')
    end

    it "preserves target and rel attributes" do
      ad =
        AdPlugin::HouseAd.create!(
          valid_attrs.merge(
            html: '<a href="https://example.com" target="_blank" rel="noopener">Link</a>',
          ),
        )
      expect(ad.html).to include('target="_blank"')
      expect(ad.html).to include('rel="noopener"')
    end

    it "preserves table elements" do
      html =
        "<table><thead><tr><th>Header</th></tr></thead><tbody><tr><td>Cell</td></tr></tbody></table>"
      ad = AdPlugin::HouseAd.create!(valid_attrs.merge(html: html))
      expect(ad.html).to include("<table>")
      expect(ad.html).to include("<th>Header</th>")
      expect(ad.html).to include("<td>Cell</td>")
    end

    it "preserves iframe with non-JS src" do
      ad =
        AdPlugin::HouseAd.create!(
          valid_attrs.merge(html: '<iframe src="https://example.com/embed" width="100%"></iframe>'),
        )
      expect(ad.html).to include("<iframe")
      expect(ad.html).to include('src="https://example.com/embed"')
    end

    it "preserves video/audio/source elements" do
      html = '<video controls><source src="video.mp4" type="video/mp4"></video>'
      ad = AdPlugin::HouseAd.create!(valid_attrs.merge(html: html))
      expect(ad.html).to include("<video")
      expect(ad.html).to include("<source")
    end

    it "preserves semantic elements" do
      html =
        "<section><header><nav>Menu</nav></header><article><footer>Footer</footer></article></section>"
      ad = AdPlugin::HouseAd.create!(valid_attrs.merge(html: html))
      expect(ad.html).to include("<section>")
      expect(ad.html).to include("<header>")
      expect(ad.html).to include("<nav>")
      expect(ad.html).to include("<article>")
      expect(ad.html).to include("<footer>")
    end
  end

  describe "routes" do
    let(:ad) { AdPlugin::HouseAd.create(valid_attrs) }

    it "returns route names" do
      ad.routes.create!(route_name: "discovery.latest")
      ad.routes.create!(route_name: "topic.show")

      expect(ad.route_names).to contain_exactly("discovery.latest", "topic.show")
    end

    it "replaces routes cleanly" do
      ad.routes.create!(route_name: "discovery.latest")

      ad.routes.delete_all
      ad.routes.create!(route_name: "discovery.top")

      expect(ad.reload.route_names).to eq(["discovery.top"])
    end

    it "deletes routes when the ad is destroyed" do
      ad.routes.create!(route_name: "discovery.latest")

      expect { ad.destroy }.to change { AdPlugin::HouseAdRoute.count }.by(-1)
    end
  end
end
