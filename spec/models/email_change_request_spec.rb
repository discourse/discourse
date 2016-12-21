require 'rails_helper'

RSpec.describe EmailChangeRequest do
  context 'validations' do
    describe '#new_email' do
      describe 'when email is invalid' do
        it 'should not be valid' do
          email_change_request = Fabricate.build(:email_change_request, new_email: 'testdiscourse.org')
          expect(email_change_request).to_not be_valid
        end
      end
    end
  end
end
