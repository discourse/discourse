require 'rails_helper'

describe ::DiscoursePoll::PollsValidator do
  let(:post) { Fabricate(:post) }
  subject { described_class.new(post) }

  describe "#validate_polls" do
    it "should ensure that polls have unique names" do
      raw = <<~RAW
      [poll]
      * 1
      * 2
      [/poll]

      [poll]
      * 1
      * 2
      [/poll]
      RAW

      expect(post.update_attributes(raw: raw)).to eq(false)

      expect(post.errors[:base]).to include(
        I18n.t("poll.multiple_polls_without_name")
      )

      raw = <<~RAW
      [poll name=test]
      * 1
      * 2
      [/poll]

      [poll name=test]
      * 1
      * 2
      [/poll]
      RAW

      expect(post.update_attributes(raw: raw)).to eq(false)

      expect(post.errors[:base]).to include(
        I18n.t("poll.multiple_polls_with_same_name", name: 'test')
      )
    end

    it 'should ensure that polls have unique options' do
      raw = <<~RAW
      [poll]
      * 1
      * 1
      [/poll]
      RAW

      expect(post.update_attributes(raw: raw)).to eq(false)

      expect(post.errors[:base]).to include(
        I18n.t("poll.default_poll_must_have_different_options")
      )

      raw = <<~RAW
      [poll name=test]
      * 1
      * 1
      [/poll]
      RAW

      expect(post.update_attributes(raw: raw)).to eq(false)

      expect(post.errors[:base]).to include(
        I18n.t("poll.named_poll_must_have_different_options", name: 'test')
      )
    end

    it 'should ensure that polls have at least 2 options' do
      raw = <<~RAW
      [poll]
      * 1
      [/poll]
      RAW

      expect(post.update_attributes(raw: raw)).to eq(false)

      expect(post.errors[:base]).to include(
        I18n.t("poll.default_poll_must_have_at_least_2_options")
      )

      raw = <<~RAW
      [poll name=test]
      * 1
      [/poll]
      RAW

      expect(post.update_attributes(raw: raw)).to eq(false)

      expect(post.errors[:base]).to include(
        I18n.t("poll.named_poll_must_have_at_least_2_options", name: 'test')
      )
    end

    it "should ensure that polls' options do not exceed site settings" do
      SiteSetting.poll_maximum_options = 2

      raw = <<~RAW
      [poll]
      * 1
      * 2
      * 3
      [/poll]
      RAW

      expect(post.update_attributes(raw: raw)).to eq(false)

      expect(post.errors[:base]).to include(I18n.t(
        "poll.default_poll_must_have_less_options",
        count: SiteSetting.poll_maximum_options
      ))

      raw = <<~RAW
      [poll name=test]
      * 1
      * 2
      * 3
      [/poll]
      RAW

      expect(post.update_attributes(raw: raw)).to eq(false)

      expect(post.errors[:base]).to include(I18n.t(
        "poll.named_poll_must_have_less_options",
        name: 'test', count: SiteSetting.poll_maximum_options
      ))
    end

    describe 'multiple type polls' do
      it "should ensure that min should not be greater than max" do
        raw = <<~RAW
        [poll type=multiple min=2 max=1]
        * 1
        * 2
        * 3
        [/poll]
        RAW

        expect(post.update_attributes(raw: raw)).to eq(false)

        expect(post.errors[:base]).to include(
          I18n.t("poll.default_poll_with_multiple_choices_has_invalid_parameters")
        )

        raw = <<~RAW
        [poll type=multiple min=2 max=1 name=test]
        * 1
        * 2
        * 3
        [/poll]
        RAW

        expect(post.update_attributes(raw: raw)).to eq(false)

        expect(post.errors[:base]).to include(
          I18n.t("poll.named_poll_with_multiple_choices_has_invalid_parameters", name: 'test')
        )
      end

      it "should ensure max setting is greater than 0" do
        raw = <<~RAW
        [poll type=multiple max=-2]
        * 1
        * 2
        [/poll]
        RAW

        expect(post.update_attributes(raw: raw)).to eq(false)

        expect(post.errors[:base]).to include(
          I18n.t("poll.default_poll_with_multiple_choices_has_invalid_parameters")
        )
      end

      it "should ensure that max settings is smaller or equal to the number of options" do
        raw = <<~RAW
        [poll type=multiple max=3]
        * 1
        * 2
        [/poll]
        RAW

        expect(post.update_attributes(raw: raw)).to eq(false)

        expect(post.errors[:base]).to include(
          I18n.t("poll.default_poll_with_multiple_choices_has_invalid_parameters")
        )
      end

      it "should ensure that min settings is not negative" do
        raw = <<~RAW
        [poll type=multiple min=-1]
        * 1
        * 2
        [/poll]
        RAW

        expect(post.update_attributes(raw: raw)).to eq(false)

        expect(post.errors[:base]).to include(
          I18n.t("poll.default_poll_with_multiple_choices_has_invalid_parameters")
        )
      end

      it "should ensure that min settings it not equal to zero" do
        raw = <<~RAW
        [poll type=multiple min=0]
        * 1
        * 2
        [/poll]
        RAW

        expect(post.update_attributes(raw: raw)).to eq(false)

        expect(post.errors[:base]).to include(
          I18n.t("poll.default_poll_with_multiple_choices_has_invalid_parameters")
        )
      end

      it "should ensure that min settings is not equal to the number of options" do
        raw = <<~RAW
        [poll type=multiple min=2]
        * 1
        * 2
        [/poll]
        RAW

        expect(post.update_attributes(raw: raw)).to eq(false)

        expect(post.errors[:base]).to include(
          I18n.t("poll.default_poll_with_multiple_choices_has_invalid_parameters")
        )
      end

      it "should ensure that min settings is not greater than the number of options" do
        raw = <<~RAW
        [poll type=multiple min=3]
        * 1
        * 2
        [/poll]
        RAW

        expect(post.update_attributes(raw: raw)).to eq(false)

        expect(post.errors[:base]).to include(
          I18n.t("poll.default_poll_with_multiple_choices_has_invalid_parameters")
        )
      end
    end
  end
end
