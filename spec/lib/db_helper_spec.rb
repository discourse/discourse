# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DbHelper do
  describe '.remap' do
    it 'should remap columns properly' do
      post = Fabricate(:post, cooked: "this is a specialcode that I included")
      post_attributes = post.reload.attributes
      post2 = Fabricate(:post, image_url: "/testing/specialcode")
      post2_attributes = post2.reload.attributes

      badge = Fabricate(:badge, query: "specialcode")
      badge_attributes = badge.reload.attributes

      DbHelper.remap("specialcode", "codespecial")

      post.reload

      expect(post.cooked).to include("codespecial")

      post2.reload

      expect(post2.image_url).to eq("/testing/codespecial")

      expect(post2_attributes.except("image_url"))
        .to eq(post2.attributes.except("image_url"))

      badge.reload

      expect(badge.query).to eq("codespecial")

      expect(badge_attributes.except("query"))
        .to eq(badge.attributes.except("query"))
    end

    it 'allows tables to be excluded from scanning' do
      post = Fabricate(:post, cooked: "test")

      DbHelper.remap("test", "something else", excluded_tables: %w{posts})

      expect(post.reload.cooked).to eq('test')
    end

    it "does not remap readonly columns" do
      post = Fabricate(:post, raw: "This is a test", cooked: "This is a test")

      Migration::ColumnDropper.mark_readonly("posts", "cooked")

      DbHelper.remap("test", "something else")

      post.reload

      expect(post.raw).to eq("This is a something else")
      expect(post.cooked).to eq("This is a test")

      DB.exec "DROP FUNCTION #{Migration::BaseDropper.readonly_function_name("posts", "cooked")} CASCADE"
    end
  end

  describe ".regexp_replace" do
    it "should remap columns correctly" do
      post = Fabricate(:post, raw: "this is a [img]test[/img] post")

      DbHelper.regexp_replace("\\[img\\]test\\[/img\\]", "[img]something[/img]")

      expect(post.reload.raw).to include("[img]something[/img]")
    end
  end
end
