require 'rails_helper'
require_dependency 'discourse_tagging'

describe DiscourseTagging do
  let(:user)     { Fabricate(:user) }
  let(:guardian) { Guardian.new(user) }

  describe '#tags_for_saving' do
    it "returns empty array if input is nil" do
      expect(described_class.tags_for_saving(nil, guardian)).to eq([])
    end

    it "returns empty array if input is empty" do
      expect(described_class.tags_for_saving([], guardian)).to eq([])
    end

    it "returns empty array if can't tag topics" do
      guardian.stubs(:can_tag_topics?).returns(false)
      expect(described_class.tags_for_saving(['newtag'], guardian)).to eq([])
    end

    context "can tag topics but not create tags" do
      before do
        guardian.stubs(:can_create_tag?).returns(false)
        guardian.stubs(:can_tag_topics?).returns(true)
      end

      it "returns empty array if all tags are new" do
        expect(described_class.tags_for_saving(['newtag', 'newtagplz'], guardian)).to eq([])
      end

      it "returns only existing tag names" do
        Fabricate(:tag, name: 'oldtag')
        expect(described_class.tags_for_saving(['newtag', 'oldtag'], guardian).try(:sort)).to eq(['oldtag'])
      end
    end

    context "can tag topics and create tags" do
      before do
        guardian.stubs(:can_create_tag?).returns(true)
        guardian.stubs(:can_tag_topics?).returns(true)
      end

      it "returns given tag names if can create new tags and tag topics" do
        expect(described_class.tags_for_saving(['newtag1', 'newtag2'], guardian).try(:sort)).to eq(['newtag1', 'newtag2'])
      end

      it "only sanitizes new tags" do # for backwards compat
        Tag.new(name: 'math=fun').save(validate: false)
        expect(described_class.tags_for_saving(['math=fun', 'fun*2@gmail.com'], guardian).try(:sort)).to eq(['math=fun', 'fun2gmailcom'].sort)
      end
    end
  end
end
