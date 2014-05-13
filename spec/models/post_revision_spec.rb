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

  it "can grab history from current object" do
    p = PostRevision.new(modifications: {"foo" => ["bar", "bar1"]})
    p.previous("foo").should == "bar"
    p.current("foo").should == "bar1"
  end

  it "can fallback to previous revisions if needed" do
    create_rev("foo" => ["A", "B"])
    r2 = create_rev("bar" => ["C", "D"])

    r2.current("foo").should == "B"
    r2.previous("foo").should == "B"
  end

  it "can fallback to post if needed" do
    post = Fabricate(:post)
    r = create_rev({"foo" => ["A", "B"]}, post.id)

    r.current("raw").should == post.raw
    r.previous("raw").should == post.raw
    r.current("cooked").should == post.cooked
    r.previous("cooked").should == post.cooked
  end

  it "can fallback to topic if needed" do
    post = Fabricate(:post)
    r = create_rev({"foo" => ["A", "B"]}, post.id)

    r.current("title").should == post.topic.title
    r.previous("title").should == post.topic.title
  end

  it "can find title changes" do
    r = create_rev({"title" => ["hello", "frog"]})
    r.title_changes[:inline].should =~ /frog.*hello/
    r.title_changes[:side_by_side].should =~ /hello.*frog/
  end

  it "can find category changes" do
    cat1 = Fabricate(:category, name: "cat1")
    cat2 = Fabricate(:category, name: "cat2")

    r = create_rev({"category_id" => [cat1.id, cat2.id]})

    changes = r.category_changes
    changes[:previous_category_id].should == cat1.id
    changes[:current_category_id].should == cat2.id

  end

  it "can find wiki changes" do
    r = create_rev("wiki" => [false, true])

    changes = r.wiki_changes
    changes[:previous_wiki].should be_false
    changes[:current_wiki].should be_true
  end

end
