# frozen_string_literal: true

RSpec.describe Onebox::Engine::VimeoOnebox do
  def get_response(filename)
    file = "#{Rails.root}/plugins/discourse-lazy-videos/spec/fixtures/#{filename}.response"
    File.read(file)
  end

  before do
    stub_request(:get, "https://vimeo.com/786646692").to_return(
      status: 200,
      body: get_response("vimeo"),
    )

    stub_request(:get, "https://vimeo.com/192207770/0faf1dd09d").to_return(
      status: 200,
      body: get_response("vimeo-unlisted"),
    )

    stub_request(
      :get,
      "https://vimeo.com/api/oembed.json?url=https://vimeo.com/786646692",
    ).to_return(
      status: 200,
      body:
        JSON.dump(
          type: "video",
          version: "1.0",
          provider_name: "Vimeo",
          provider_url: "https://vimeo.com/",
          title: "Dear Rich",
          author_name: "Stept Studios",
          author_url: "https://vimeo.com/steptstudios",
          is_plus: "0",
          account_type: "business",
          html:
            "<iframe src=\"https://player.vimeo.com/video/786646692?h=f2ca1d6121&amp;app_id=122963\" width=\"426\" height=\"240\" frameborder=\"0\" allow=\"autoplay; fullscreen; picture-in-picture\" allowfullscreen title=\"Dear Rich\"></iframe>",
          width: 426,
          height: 240,
          duration: 883,
          description:
            "Accomplished endurance athlete, author and podcaster, Rich Roll has been a voice we have become familiar with over the years. In DEAR RICH, we hear the story behind the voice. Rich shares a letter to himself, giving an intimate view into the struggles he's faced with addiction, how running has helped bring him back to the surface and something that he is still learning: that we must overcome our fear of change to find what we are truly capable of.\n\n\n\n\nCredits: \nClient: SalomonTV\nProduction Company: Stept Studios\nPost Production: Lockt Editorial\n\n\nDirector: Brandon Lavoie\nDP: Jared Levy \nEP: Jon Brogan \nAccount Executive: Paul Muhlbach\nProducer: Laura Mittelberg\nSupervising Producer: Eric Cook \n1st AC: Jake Coury\nGaffer: Evan Cox\nKey Grip: David Klassen \nHMU: Luca Buzas\nAudio Mixer: Bobby Vongham\n35mm Photographer: Brian Chorski\t\nPA: Anthony Cantu, John Maddock\n\nPost Production\nHead of Post: Connor Scofield\nPost EP: Eileen Miraglia\nPost Producer: Erin Bates\nEditor: Brandon Lavoie\nOnline Editor: Ben Ivers\nColorist: Sam Zook at Mom & Pop\nComposer: Jon Sigsworth\nSound Design and Mix: Justin Enoch at Post Mambo\n\n\nSalomonTV\nSenior Marketing Manager – Run & Outdoor: Erin Cooper\nMarketing Specialist: Louis Bertrand",
          thumbnail_url:
            "https://i.vimeocdn.com/video/1582157011-37115b15c717a168bf86e2f2855b6bbc23b1cbcee54ff99c8d7b808b459365d6-d_295x166",
          thumbnail_width: 295,
          thumbnail_height: 166,
          thumbnail_url_with_play_button:
            "https://i.vimeocdn.com/filter/overlay?src0=https%3A%2F%2Fi.vimeocdn.com%2Fvideo%2F1582157011-37115b15c717a168bf86e2f2855b6bbc23b1cbcee54ff99c8d7b808b459365d6-d_295x166&src1=http%3A%2F%2Ff.vimeocdn.com%2Fp%2Fimages%2Fcrawler_play.png",
          upload_date: "2023-01-05 12:01:55",
          video_id: 786_646_692,
          uri: "/videos/786646692",
        ),
    )

    stub_request(
      :get,
      "https://vimeo.com/api/oembed.json?url=https://vimeo.com/192207770/0faf1dd09d",
    ).to_return(
      status: 200,
      body:
        JSON.dump(
          type: "video",
          version: "1.0",
          provider_name: "Vimeo",
          provider_url: "https://vimeo.com/",
          html:
            "<iframe src=\"https://player.vimeo.com/video/192207770?h=0faf1dd09d&amp;app_id=122963\" width=\"640\" height=\"272\" frameborder=\"0\" allow=\"autoplay; fullscreen; picture-in-picture\" allowfullscreen></iframe>",
          width: 640,
          height: 272,
          video_id: 192_207_770,
          uri: "/videos/192207770:0faf1dd09d",
        ),
    )
  end

  context "when public video" do
    it "creates a lazy video container" do
      expect(Onebox.preview("https://vimeo.com/786646692").to_s).to match(/lazy-video-container/)
    end

    it "uses the correct ids" do
      expect(Onebox.preview("https://vimeo.com/786646692").to_s).to include(
        'data-video-id="786646692"',
      )
      expect(Onebox.preview("https://vimeo.com/786646692").to_s).to include(
        'src="https://vumbnail.com/786646692.jpg"',
      )
    end
  end

  context "when unlisted video" do
    it "creates a lazy video container" do
      expect(Onebox.preview("https://vimeo.com/192207770/0faf1dd09d").to_s).to match(
        /lazy-video-container/,
      )
    end

    it "uses the correct ids" do
      expect(Onebox.preview("https://vimeo.com/192207770/0faf1dd09d").to_s).to include(
        'data-video-id="192207770?h=0faf1dd09d&amp;app_id=122963"',
      )
      expect(Onebox.preview("https://vimeo.com/192207770/0faf1dd09d").to_s).to include(
        'src="https://vumbnail.com/192207770.jpg"',
      )
    end
  end
end
