# encoding: utf-8

require 'spec_helper'

require 'slug'

describe Slug do


  it 'replaces spaces with hyphens' do
    Slug.for("hello world").should == 'hello-world'
  end

  it 'changes accented characters' do
    Slug.for('àllo').should == 'allo'
  end

  it 'removes symbols' do
    Slug.for('evil#trout').should == 'eviltrout'
  end

  it 'handles a.b.c properly' do 
    Slug.for("a.b.c").should == "a-b-c"
  end

  it 'handles double dots right' do 
    Slug.for("a....b.....c").should == "a-b-c"
  end


end

