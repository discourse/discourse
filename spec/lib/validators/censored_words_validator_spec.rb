# frozen_string_literal: true

require 'rails_helper'

describe CensoredWordsValidator do
  let(:value) { 'some new bad text' }
  let(:record) { Fabricate(:post, raw: 'this is a test') }
  let(:attribute) { :raw }

  describe "#validate_each" do
    context "when there are censored words for action" do
      let!(:watched_word) { Fabricate(:watched_word, action: WatchedWord.actions[:censor], word: 'bad') }

      context "when there is a nil word_matcher_regexp" do
        before do
          WordWatcher.stubs(:word_matcher_regexp).returns(nil)
        end

        it "adds no errors to the record" do
          validate
          expect(record.errors.empty?).to eq(true)
        end
      end

      context "when there is word_matcher_regexp" do
        context "when the new value does not contain the watched word" do
          let(:value) { 'some new good text' }

          it "adds no errors to the record" do
            validate
            expect(record.errors.empty?).to eq(true)
          end
        end

        context "when the new value does contain the watched word" do
          let(:value) { 'some new bad text' }

          it "adds errors to the record" do
            validate
            expect(record.errors.empty?).to eq(false)
          end
        end
      end
    end
  end

  def validate
    described_class.new(attributes: :test).validate_each(record, attribute, value)
  end
end
