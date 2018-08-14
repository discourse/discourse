require 'rails_helper'

RSpec.describe SkippedEmailLog, type: :model do
  let(:custom_skipped_email_log) do
    Fabricate.build(:skipped_email_log,
      reason_type: SkippedEmailLog.reason_types[:custom]
    )
  end

  let(:skipped_email_log) { Fabricate.build(:skipped_email_log) }

  describe 'validations' do
    it { is_expected.to validate_presence_of(:email_type) }
    it { is_expected.to validate_presence_of(:to_address) }
    it { is_expected.to validate_presence_of(:reason_type) }

    describe '#reason_type' do
      describe 'when reason_type is not valid' do
        it 'should not be valid' do
          skipped_email_log.reason_type = 999999

          expect(skipped_email_log.valid?).to eq(false)
          expect(skipped_email_log.errors.messages).to include(:reason_type)
        end
      end
    end

    describe '#custom_reason' do
      describe 'when log is a custom reason type' do
        describe 'when custom reason is blank' do
          it 'should not be valid' do
            expect(custom_skipped_email_log.valid?).to eq(false)

            expect(custom_skipped_email_log.errors.messages)
              .to include(:custom_reason)
          end
        end

        describe 'when custom reason is not blank' do
          it 'should be valid' do
            custom_skipped_email_log.custom_reason = 'test'

            expect(custom_skipped_email_log.valid?).to eq(true)
          end
        end
      end

      describe 'when log is not a custom reason type' do
        describe 'when custom reason is blank' do
          it 'should be valid' do
            expect(skipped_email_log.valid?).to eq(true)
          end
        end

        describe 'when custom reason is not blank' do
          it 'should not be valid' do
            skipped_email_log.custom_reason = 'test'

            expect(skipped_email_log.valid?).to eq(false)
            expect(skipped_email_log.errors.messages).to include(:custom_reason)
          end
        end
      end
    end
  end

  describe '.reason_types' do
    describe "verify enum sequence" do
      it 'should return the right sequence' do
        expect(SkippedEmailLog.reason_types[:custom]).to eq(1)
        expect(SkippedEmailLog.reason_types[:user_email_already_read]).to eq(15)
      end
    end
  end

  describe '#reason' do
    describe 'for a custom log' do
      it 'should return the right output' do
        custom_skipped_email_log.custom_reason = 'test'
        expect(custom_skipped_email_log.reason).to eq('test')
      end
    end

    describe 'for a non custom log' do
      it 'should return the right output' do
        expect(skipped_email_log.reason).to eq("
          #{I18n.t('skipped_email_log.exceeded_emails_limit')}
        ".strip)

        skipped_email_log.reason_type =
          SkippedEmailLog.reason_types[:user_email_no_user]

        skipped_email_log.user_id = 9999

        expect(skipped_email_log.reason).to eq("
          #{I18n.t(
            'skipped_email_log.user_email_no_user', user_id: 9999
          )}
        ".strip)
      end
    end
  end
end
