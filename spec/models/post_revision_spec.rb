require 'spec_helper'
require_dependency 'post_revision'

describe PostRevision do

  before do
    @number = 1
  end

  def create_rev(modifications, post_id=1)
    @number += 1
    PostRevision.create!(post_id: post_id, user_id: 1, number: @number, modifications: modifications)
  end

  it "ignores deprecated current values in history" do
    p = PostRevision.new(modifications: {"foo" => ["bar", "bar1"]})
    p.previous("foo").should == "bar"
    p.current("foo").should == "bar"
  end

  it "can fallback to previous revisions if needed" do
    r1 = create_rev("foo" => ["A", "B"])
    r2 = create_rev("foo" => ["C", "D"])

    r1.current("foo").should == "C"
    r2.current("foo").should == "C"
    r2.previous("foo").should == "C"
  end

  it "can fallback to post if needed" do
    post = Fabricate(:post)
    r = create_rev({"foo" => ["A", "B"]}, post.id)

    r.current("raw").should == post.raw
    r.previous("raw").should == post.raw
    r.current("cooked").should == post.cooked
    r.previous("cooked").should == post.cooked
  end

  it "can fallback to post for current rev only if needed" do
    post = Fabricate(:post)
    r = create_rev({"raw" => ["A"], "cooked" => ["AA"]}, post.id)

    r.current("raw").should == post.raw
    r.previous("raw").should == "A"
    r.current("cooked").should == post.cooked
    r.previous("cooked").should == "AA"
  end

  it "can fallback to topic if needed" do
    post = Fabricate(:post)
    r = create_rev({"foo" => ["A", "B"]}, post.id)

    r.current("title").should == post.topic.title
    r.previous("title").should == post.topic.title
  end

  it "can find title changes" do
    r1 = create_rev({"title" => ["hello"]})
    r2 = create_rev({"title" => ["frog"]})
    r1.title_changes[:inline].should =~ /frog.*hello/
    r1.title_changes[:side_by_side].should =~ /hello.*frog/
  end

  it "can find category changes" do
    cat1 = Fabricate(:category, name: "cat1")
    cat2 = Fabricate(:category, name: "cat2")

    r1 = create_rev({"category_id" => [cat1.id, cat2.id]})
    r2 = create_rev({"category_id" => [cat2.id, cat1.id]})

    changes = r1.category_changes
    changes[:previous_category_id].should == cat1.id
    changes[:current_category_id].should == cat2.id

  end

  it "can find wiki changes" do
    r1 = create_rev("wiki" => [false])
    r2 = create_rev("wiki" => [true])

    changes = r1.wiki_changes
    changes[:previous_wiki].should == false
    changes[:current_wiki].should == true
  end

  it "can find post_type changes" do
    r1 = create_rev("post_type" => [1])
    r2 = create_rev("post_type" => [2])

    changes = r1.post_type_changes
    changes[:previous_post_type].should == 1
    changes[:current_post_type].should == 2
  end

  it "hides revisions that were hidden" do
    r1 = create_rev({"raw" => ["one"]})
    r2 = create_rev({"raw" => ["two"]})
    r3 = create_rev({"raw" => ["three"]})

    r2.hide!

    r1.current("raw").should == "three"
    r2.previous("raw").should == "one"
  end

  it "shows revisions that were shown" do
    r1 = create_rev({"raw" => ["one"]})
    r2 = create_rev({"raw" => ["two"]})
    r3 = create_rev({"raw" => ["three"]})

    r2.hide!
    r2.show!

    r2.previous("raw").should == "two"
    r1.current("raw").should == "two"
  end

end
