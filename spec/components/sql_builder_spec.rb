# encoding: utf-8
require 'rails_helper'
require_dependency 'sql_builder'

describe SqlBuilder do

  describe "attached" do
    before do
      @builder = Post.sql_builder("select * from posts /*where*/ /*limit*/")
    end

    it "should find a post by id" do
      p = Fabricate(:post)
      @builder.where('id = :id and topic_id = :topic_id', id: p.id, topic_id: p.topic_id)
      p2 = @builder.exec.first
      expect(p2.id).to eq(p.id)
      expect(p2).to eq(p)
    end
  end

  describe "map_exec" do
    class SqlBuilder::TestClass
      attr_accessor :int, :string, :date, :text, :bool
    end

    it "correctly maps to a klass" do
      rows = SqlBuilder.new("SELECT
                            1 AS int,
                            'string' AS string,
                            CAST(NOW() at time zone 'utc' AS timestamp without time zone) AS date,
                            'text'::text AS text,
                            true AS bool")
        .map_exec(SqlBuilder::TestClass)

      expect(rows.count).to eq(1)
      row = rows[0]
      expect(row.int).to eq(1)
      expect(row.string).to eq("string")
      expect(row.text).to eq("text")
      expect(row.bool).to eq(true)
      expect(row.date).to be_within(10.seconds).of(DateTime.now)
    end
  end

  describe "detached" do
    before do
      @builder = SqlBuilder.new("select * from (select :a A union all select :b) as X /*where*/ /*order_by*/ /*limit*/ /*offset*/")
    end

    it "should allow for 1 param exec" do
      expect(@builder.exec(a: 1, b: 2).values[0][0]).to eq('1')
    end

    it "should allow for a single where" do
      @builder.where(":a = 1")
      expect(@builder.exec(a: 1, b: 2).values[0][0]).to eq('1')
    end

    it "should allow where chaining" do
      @builder.where(":a = 1")
      @builder.where("2 = 1")
      expect(@builder.exec(a: 1, b: 2).to_a.length).to eq(0)
    end

    it "should allow order by" do
      expect(@builder.order_by("A desc").limit(1)
        .exec(a:1, b:2).values[0][0]).to eq("2")
    end
    it "should allow offset" do
      expect(@builder.order_by("A desc").offset(1)
        .exec(a:1, b:2).values[0][0]).to eq("1")
    end
  end

end
