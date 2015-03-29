# encoding: utf-8

require 'spec_helper'
require 'slug'

describe Slug do

  it 'replaces spaces with hyphens' do
    expect(Slug.for("hello world")).to eq('hello-world')
  end

  it 'changes accented characters' do
    expect(Slug.for('àllo')).to eq('allo')
  end

  it 'replaces symbols' do
    expect(Slug.for('evil#trout')).to eq('evil-trout')
  end

  it 'handles a.b.c properly' do
    expect(Slug.for("a.b.c")).to eq("a-b-c")
  end

  it 'handles double dots right' do
    expect(Slug.for("a....b.....c")).to eq("a-b-c")
  end

  it 'strips trailing punctuation' do
    expect(Slug.for("hello...")).to eq("hello")
  end

  it 'strips leading punctuation' do
    expect(Slug.for("...hello")).to eq("hello")
  end

  it 'handles our initial transliteration' do
    from = "àáäâčďèéëěêìíïîľĺňòóöôŕřšťůùúüûýžñç"
    to   = "aaaacdeeeeeiiiillnoooorrstuuuuuyznc"
    expect(Slug.for(from)).to eq(to)
  end

  it 'replaces underscores' do
    expect(Slug.for("o_o_o")).to eq("o-o-o")
  end

  it "doesn't generate slugs that are just numbers" do
    expect(Slug.for('123')).to be_blank
  end

  it "doesn't generate slugs that are just numbers" do
    expect(Slug.for('2')).to be_blank
  end

  it "doesn't keep single quotes within word" do
    expect(Slug.for("Jeff hate's this")).to eq("jeff-hates-this")
  end

  it "translate the chineses" do
    SiteSetting.default_locale = 'zh_CN'
    expect(Slug.for("习近平:中企承建港口电站等助斯里兰卡发展")).to eq("xi-jin-ping-zhong-qi-cheng-jian-gang-kou-dian-zhan-deng-zhu-si-li-lan-qia-fa-zhan")
  end

end

