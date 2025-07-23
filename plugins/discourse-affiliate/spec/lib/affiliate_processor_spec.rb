# frozen_string_literal: true

describe AffiliateProcessor do
  def r(url)
    AffiliateProcessor.apply(url)
  end

  before { enable_current_plugin }

  it "can apply affiliate code to ldlc" do
    SiteSetting.affiliate_ldlc_com = "samsshop"

    expect(r("http://www.ldlc.com/some_product?xyz=1")).to eq(
      "http://www.ldlc.com/some_product?xyz=1#samsshop",
    )
    expect(r("https://ldlc.com/some_product?xyz=1")).to eq(
      "https://ldlc.com/some_product?xyz=1#samsshop",
    )
  end

  it "can apply affiliate code correctly to amazon" do
    SiteSetting.affiliate_amazon_com = "sams-shop"
    SiteSetting.affiliate_amazon_ca = "ca-sams-shop"
    SiteSetting.affiliate_amazon_com_au = "au-sams-shop"
    SiteSetting.affiliate_amazon_eu = "eu-sams-shop"

    expect(r("https://www.amazon.com")).to eq("https://www.amazon.com?tag=sams-shop")
    expect(r("http://www.amazon.com/some_product?xyz=1")).to eq(
      "http://www.amazon.com/some_product?tag=sams-shop",
    )
    expect(r("https://www.amazon.com/some_product?xyz=1")).to eq(
      "https://www.amazon.com/some_product?tag=sams-shop",
    )
    expect(r("https://www.amazon.com?hello=1&tag=bobs-shop")).to eq(
      "https://www.amazon.com?tag=sams-shop",
    )
    expect(r("https://amzn.com/some_product?xyz=1")).to eq(
      "https://amzn.com/some_product?tag=sams-shop",
    )
    expect(r("https://smile.amazon.com/some_product?xyz=1")).to eq(
      "https://smile.amazon.com/some_product?tag=sams-shop",
    )
    expect(r("https://www.amazon.com.au/some_product?xyz=1")).to eq(
      "https://www.amazon.com.au/some_product?tag=au-sams-shop",
    )
    expect(
      r(
        "https://www.amazon.ca/Dragon-Quest-Echoes-Elusive-Age-PlayStation/dp/B07BP3J6RG/ref=br_asw_pdt-5?pf_rd_m=ATVPDKIKX0DER&pf_rd_s=&pf_rd_r=XFGPRSG0SVD5K3RKX5T3&pf_rd_t=36701&pf_rd_p=f8585743-c043-4665-80a7-0cc5fe97d596&pf_rd_i=desktop&th=1",
      ),
    ).to eq(
      "https://www.amazon.ca/Dragon-Quest-Echoes-Elusive-Age-PlayStation/dp/B07BP3J6RG/ref=br_asw_pdt-5?tag=ca-sams-shop",
    )
    expect(r("https://amzn.to/d/some_short_link")).to eq(
      "https://amzn.to/d/some_short_link?tag=sams-shop",
    )
    expect(r("https://amzn.eu/d/some_short_link")).to eq(
      "https://amzn.eu/d/some_short_link?tag=eu-sams-shop",
    )
    expect(r("https://a.co/some_short_link")).to eq("https://a.co/some_short_link?tag=sams-shop")

    # keep node (BrowseNodeSearch) query parameter
    expect(r("https://www.amazon.com/b?ie=UTF8&node=13548845011")).to eq(
      "https://www.amazon.com/b?tag=sams-shop&node=13548845011",
    )
  end

  it "can apply codes to post in post processor" do
    Jobs.run_immediately!
    SiteSetting.affiliate_amazon_com = "sams-shop"

    stub_request(:get, "http://www.amazon.com/link?testing").to_return(status: 200, body: "")
    post = create_post(raw: "this is an www.amazon.com/link?testing yay")
    post.reload

    expect(post.cooked.scan("sams-shop").length).to eq(1)
  end
end
