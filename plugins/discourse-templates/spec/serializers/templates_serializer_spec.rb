# frozen_string_literal: true

require "rails_helper"
require_relative "../helpers/topics_helper"

RSpec.configure { |c| c.include DiscourseTemplates::TopicsHelper }

describe DiscourseTemplates::TemplatesSerializer do
  fab!(:template_item) # uncategorized
  fab!(:tag1) { Fabricate(:tag, topics: [template_item], name: "tag1") }
  fab!(:tag2) { Fabricate(:tag, topics: [template_item], name: "tag2") }

  subject(:serializer) { described_class.new(template_item, root: false) }

  context "when serializing templates" do
    it "serializes correctly to json including tags when tagging is enabled" do
      SiteSetting.tagging_enabled = true

      json = serializer.as_json
      expect(json).to have_key(:tags)

      expect(json[:id]).to eq(template_item.id)
      expect(json[:title]).to eq(template_item.title)
      expect(json[:slug]).to eq(template_item.slug)
      expect(json[:content]).to eq(template_item.first_post.raw)
      expect(json[:tags]).to match_array(template_item.tags.map(&:name))
      expect(json[:usages]).to eq(0)
    end

    it "serializes correctly to json excluding tags when tagging is disabled" do
      SiteSetting.tagging_enabled = false

      json = serializer.as_json
      expect(json).to_not have_key(:tags)

      expect(json[:id]).to eq(template_item.id)
      expect(json[:title]).to eq(template_item.title)
      expect(json[:slug]).to eq(template_item.slug)
      expect(json[:content]).to eq(template_item.first_post.raw)
      expect(json[:tags]).to eq(nil)
      expect(json[:usages]).to eq(0)
    end
  end
end
