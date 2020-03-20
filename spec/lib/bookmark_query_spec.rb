# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BookmarkQuery do
  fab!(:user) { Fabricate(:user) }
  fab!(:bookmark1) { Fabricate(:bookmark, user: user) }
  fab!(:bookmark2) { Fabricate(:bookmark, user: user) }
  let(:params) { {} }

  subject { described_class.new(user, params) }

  describe "#list_all" do
    it "returns all the bookmarks for a user" do
      expect(subject.list_all.count).to eq(2)
    end

    it "runs the on_preload block provided passing in bookmarks" do
      preloaded_bookmarks = []
      BookmarkQuery.on_preload do |bookmarks, bq|
        (preloaded_bookmarks << bookmarks).flatten
      end
      subject.list_all
      expect(preloaded_bookmarks.any?).to eq(true)
    end

    context "when the limit param is provided" do
      let(:params) { { limit: 1 } }
      it "is respected" do
        expect(subject.list_all.count).to eq(1)
      end
    end

    context "when there are topic custom fields to preload" do
      before do
        TopicCustomField.create(
          topic_id: bookmark1.topic.id, name: 'test_field', value: 'test'
        )
        BookmarkQuery.preloaded_custom_fields << "test_field"
      end
      it "preloads them" do
        Topic.expects(:preload_custom_fields)
        expect(
          subject.list_all.find do |b|
            b.topic_id = bookmark1.topic_id
          end.topic.custom_fields['test_field']
        ).not_to eq(nil)
      end
    end
  end
end
