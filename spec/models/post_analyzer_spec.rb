require 'spec_helper'

describe PostAnalyzer do

  # Help us build a post with a raw body
  def post_with_body(body, user=nil)
    args = post_args.merge(raw: body)
    args[:user] = user if user.present?
    Fabricate.build(:post, args)
  end

  let(:topic) { Fabricate(:topic) }
  let(:post_args) do
    {user: topic.user, topic: topic}
  end

  context "links" do
    let(:newuser) { Fabricate(:user, trust_level: TrustLevel.levels[:newuser]) }
    let(:no_links) { post_with_body("hello world my name is evil trout", newuser) }
    let(:one_link) { post_with_body("[jlawr](http://www.imdb.com/name/nm2225369)", newuser) }
    let(:two_links) { post_with_body("<a href='http://disneyland.disney.go.com/'>disney</a> <a href='http://reddit.com'>reddit</a>", newuser)}
    let(:three_links) { post_with_body("http://discourse.org and http://discourse.org/another_url and http://www.imdb.com/name/nm2225369", newuser)}

    describe "raw_links" do
      it "returns a blank collection for a post with no links" do
        no_links.raw_links.should be_blank
      end

      it "finds a link within markdown" do
        one_link.raw_links.should == ["http://www.imdb.com/name/nm2225369"]
      end

      it "can find two links from html" do
        two_links.raw_links.should == ["http://disneyland.disney.go.com/", "http://reddit.com"]
      end

      it "can find three links without markup" do
        three_links.raw_links.should == ["http://discourse.org", "http://discourse.org/another_url", "http://www.imdb.com/name/nm2225369"]
      end
    end

    describe "linked_hosts" do
      it "returns blank with no links" do
        no_links.linked_hosts.should be_blank
      end

      it "returns the host and a count for links" do
        two_links.linked_hosts.should == {"disneyland.disney.go.com" => 1, "reddit.com" => 1}
      end

      it "it counts properly with more than one link on the same host" do
        three_links.linked_hosts.should == {"discourse.org" => 1, "www.imdb.com" => 1}
      end
    end

    describe "total host usage" do

      it "has none for a regular post" do
        no_links.total_hosts_usage.should be_blank
      end

      context "with a previous host" do

        let(:user) { old_post.newuser }
        let(:another_disney_link) { post_with_body("[radiator springs](http://disneyland.disney.go.com/disney-california-adventure/radiator-springs-racers/)", newuser) }

        before do
          another_disney_link.save
          TopicLink.extract_from(another_disney_link)
        end

        it "contains the new post's links, PLUS the previous one" do
          two_links.total_hosts_usage.should == {'disneyland.disney.go.com' => 2, 'reddit.com' => 1}
        end

      end

    end


  end


  describe "maximum links" do
    let(:newuser) { Fabricate(:user, trust_level: TrustLevel.levels[:newuser]) }
    let(:post_one_link) { post_with_body("[sherlock](http://www.bbc.co.uk/programmes/b018ttws)", newuser) }
    let(:post_two_links) { post_with_body("<a href='http://discourse.org'>discourse</a> <a href='http://twitter.com'>twitter</a>", newuser) }
    let(:post_with_mentions) { post_with_body("hello @#{newuser.username} how are you doing?", newuser) }

    it "returns 0 links for an empty post" do
      Fabricate.build(:post).link_count.should == 0
    end

    it "returns 0 links for a post with mentions" do
      post_with_mentions.link_count.should == 0
    end

    it "finds links from markdown" do
      post_one_link.link_count.should == 1
    end

    it "finds links from HTML" do
      post_two_links.link_count.should == 2
    end

    context "validation" do

      before do
        SiteSetting.stubs(:newuser_max_links).returns(1)
      end

      context 'newuser' do
        it "returns true when within the amount of links allowed" do
          post_one_link.should be_valid
        end

        it "doesn't allow more links than allowed" do
          post_two_links.should_not be_valid
        end
      end

      it "allows multiple images for basic accounts" do
        post_two_links.user.trust_level = TrustLevel.levels[:basic]
        post_two_links.should be_valid
      end

    end

  end


  describe "@mentions" do

    context 'raw_mentions' do

      it "returns an empty array with no matches" do
        post = Fabricate.build(:post, post_args.merge(raw: "Hello Jake and Finn!"))
        post.raw_mentions.should == []
      end

      it "returns lowercase unique versions of the mentions" do
        post = Fabricate.build(:post, post_args.merge(raw: "@Jake @Finn @Jake"))
        post.raw_mentions.should == ['jake', 'finn']
      end

      it "ignores pre" do
        post = Fabricate.build(:post, post_args.merge(raw: "<pre>@Jake</pre> @Finn"))
        post.raw_mentions.should == ['finn']
      end

      it "catches content between pre tags" do
        post = Fabricate.build(:post, post_args.merge(raw: "<pre>hello</pre> @Finn <pre></pre>"))
        post.raw_mentions.should == ['finn']
      end

      it "ignores code" do
        post = Fabricate.build(:post, post_args.merge(raw: "@Jake <code>@Finn</code>"))
        post.raw_mentions.should == ['jake']
      end

      it "ignores quotes" do
        post = Fabricate.build(:post, post_args.merge(raw: "[quote=\"Evil Trout\"]@Jake[/quote] @Finn"))
        post.raw_mentions.should == ['finn']
      end

      it "handles underscore in username" do
        post = Fabricate.build(:post, post_args.merge(raw: "@Jake @Finn @Jake_Old"))
        post.raw_mentions.should == ['jake', 'finn', 'jake_old']
      end

    end

    context "max mentions" do

      let(:newuser) { Fabricate(:user, trust_level: TrustLevel.levels[:newuser]) }
      let(:post_with_one_mention) { post_with_body("@Jake is the person I'm mentioning", newuser) }
      let(:post_with_two_mentions) { post_with_body("@Jake @Finn are the people I'm mentioning", newuser) }

      context 'new user' do
        before do
          SiteSetting.stubs(:newuser_max_mentions_per_post).returns(1)
          SiteSetting.stubs(:max_mentions_per_post).returns(5)
        end

        it "allows a new user to have newuser_max_mentions_per_post mentions" do
          post_with_one_mention.should be_valid
        end

        it "doesn't allow a new user to have more than newuser_max_mentions_per_post mentions" do
          post_with_two_mentions.should_not be_valid
        end
      end

      context "not a new user" do
        before do
          SiteSetting.stubs(:newuser_max_mentions_per_post).returns(0)
          SiteSetting.stubs(:max_mentions_per_post).returns(1)
        end

        it "allows vmax_mentions_per_post mentions" do
          post_with_one_mention.user.trust_level = TrustLevel.levels[:basic]
          post_with_one_mention.should be_valid
        end

        it "doesn't allow to have more than max_mentions_per_post mentions" do
          post_with_two_mentions.user.trust_level = TrustLevel.levels[:basic]
          post_with_two_mentions.should_not be_valid
        end
      end


    end

  end
end
