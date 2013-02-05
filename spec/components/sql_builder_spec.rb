# encoding: utf-8
require 'spec_helper'
require_dependency 'sql_builder'

describe SqlBuilder do

  before do 
    @builder = SqlBuilder.new("select * from (select :a A union all select :b) as X /*where*/ /*order_by*/ /*limit*/ /*offset*/")
  end

  it "should allow for 1 param exec" do 
    @builder.exec(a: 1, b: 2).values[0][0].should == '1' 
  end

  it "should allow for a single where" do 
    @builder.where(":a = 1")
    @builder.exec(a: 1, b: 2).values[0][0].should == '1' 
  end

  it "should allow where chaining" do
    @builder.where(":a = 1")
    @builder.where("2 = 1")
    @builder.exec(a: 1, b: 2).to_a.length.should == 0
  end

  it "should allow order by" do
    @builder.order_by("A desc").limit(1)
      .exec(a:1, b:2).values[0][0].should == "2"
  end
  it "should allow offset" do
    @builder.order_by("A desc").offset(1)
      .exec(a:1, b:2).values[0][0].should == "1"
  end

end
