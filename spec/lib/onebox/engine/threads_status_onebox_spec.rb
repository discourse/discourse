# frozen_string_literal: true
RSpec.describe Onebox::Engine::ThreadsStatusOnebox do
  context "with a thread with only text" do
    let(:link) { "https://www.threads.net/t/CuVvRcttG57" }
    let(:html) { described_class.new(link).to_html }

    before do
      stub_request(:get, link).to_return(
        status: 200,
        body: onebox_response("threadsstatus_without_image"),
      )
      stub_request(:get, "https://www.threads.net/@rafael_falco").to_return(
        status: 200,
        body: onebox_response("threadsstatus_without_image"),
      )
    end

    it "includes threads content" do
      expect(html).to include("trazer a lista de follows")
    end

    it "includes name" do
      expect(html).to include("Rafael Silva")
    end

    it "includes username" do
      expect(html).to include("@rafael_falco")
    end

    it "includes user avatar" do
      expect(html).to include(
        "https://scontent.cdninstagram.com/v/t51.2885-19/358195671_1485179698889636_5420020496346583344_n.jpg?stp=dst-jpg_s150x150&amp;_nc_ht=scontent.cdninstagram.com&amp;_nc_cat=108&amp;_nc_ohc=UbFgg6blcOUAX8XVrUj&amp;edm=APs17CUBAAAA&amp;ccb=7-5&amp;oh=00_AfDTSDE1W16bDEOUCofc_RLwOXbwfwL83BafmR_f4_ou6g&amp;oe=64AB848C&amp;_nc_sid=10d13b",
      )
    end

    it "includes twitter link" do
      expect(html).to include("https://www.threads.net/t/CuVvRcttG57")
    end

    it "includes twitter likes" do
      expect(html).to include("3")
    end

    it "includes twitter retweets" do
      expect(html).to include("1")
    end
  end

  context "with a thread containing an image" do
    let(:link) { "https://www.threads.net/t/CuWRRrQuql9" }
    let(:html) { described_class.new(link).to_html }

    before do
      stub_request(:get, link).to_return(
        status: 200,
        body: onebox_response("threadsstatus_featured_image"),
      )
      stub_request(:get, "https://www.threads.net/@joyqiuu").to_return(
        status: 200,
        body: onebox_response("threadsstatus_profile"),
      )
    end

    it "includes threads content" do
      expect(html).to include("10M users later")
    end

    it "includes name" do
      expect(html).to include("Joy Qiu")
    end

    it "includes username" do
      expect(html).to include("@joyqiuu")
    end

    it "includes user avatar" do
      expect(html).to include(
        "https://scontent.cdninstagram.com/v/t51.2885-19/358167674_306426985144380_6235341132840289293_n.jpg?stp=dst-jpg_s640x640&amp;_nc_ht=scontent.cdninstagram.com&amp;_nc_cat=1&amp;_nc_ohc=KqFQdmSjeMsAX-OWNHA&amp;edm=APs17CUBAAAA&amp;ccb=7-5&amp;oh=00_AfDrfi6q0GGPALemTc0YzaE-Bnxm0GJ3QTrswCox095yRA&amp;oe=64AC85F1&amp;_nc_sid=10d13b",
      )
    end

    it "includes twitter link" do
      expect(html).to include("https://www.threads.net/t/CuWRRrQuql9")
    end

    it "includes twitter likes" do
      expect(html).to include("5.8K")
    end

    it "includes twitter retweets" do
      expect(html).to include("449")
    end
  end
end
