require 'rails_helper'

RSpec.describe Admin::EmailTemplatesController do
  let(:admin) { Fabricate(:admin) }
  let(:user) { Fabricate(:user) }

  def original_text(key)
    I18n.overrides_disabled { I18n.t(key) }
  end

  let(:original_subject) { original_text('user_notifications.admin_login.subject_template') }
  let(:original_body) { original_text('user_notifications.admin_login.text_body_template') }
  let(:headers) { { ACCEPT: 'application/json' } }

  after do
    TranslationOverride.delete_all
    I18n.reload!
  end

  context "#index" do
    it "raises an error if you aren't logged in" do
      get '/admin/customize/email_templates.json'
      expect(response.status).to eq(404)
    end

    it "raises an error if you aren't an admin" do
      sign_in(user)
      get '/admin/customize/email_templates.json'
      expect(response.status).to eq(404)
    end

    it "should work if you are an admin" do
      sign_in(admin)
      get '/admin/customize/email_templates.json'

      expect(response.status).to eq(200)

      json = ::JSON.parse(response.body)
      expect(json['email_templates']).to be_present
    end
  end

  context "#update" do
    it "raises an error if you aren't logged in" do
      put '/admin/customize/email_templates/some_id', params: {
        email_template: { subject: 'Subject', body: 'Body' }
      }, headers: headers
      expect(response.status).to eq(404)
    end

    it "raises an error if you aren't an admin" do
      sign_in(user)
      put '/admin/customize/email_templates/some_id', params: {
        email_template: { subject: 'Subject', body: 'Body' }
      }, headers: headers
      expect(response.status).to eq(404)
    end

    context "when logged in as admin" do
      before do
        sign_in(admin)
      end

      it "returns 'not found' when an unknown email template id is used" do
        put '/admin/customize/email_templates/non_existent_template', params: {
          email_template: { subject: 'Foo', body: 'Bar' }
        }, headers: headers

        expect(response).not_to be_successful

        json = ::JSON.parse(response.body)
        expect(json['error_type']).to eq('not_found')
      end

      shared_examples "invalid email template" do
        it "returns the right error messages" do
          put '/admin/customize/email_templates/user_notifications.admin_login', params: {
            email_template: { subject: email_subject, body: email_body }
          }, headers: headers

          json = ::JSON.parse(response.body)
          expect(json).to be_present

          errors = json['errors']
          expect(errors).to be_present
          expect(errors).to eq(expected_errors)
        end

        it "doesn't create translation overrides" do
          put '/admin/customize/email_templates/user_notifications.admin_login', params: {
            email_template: { subject: email_subject, body: email_body }
          }, headers: headers

          expect(I18n.t('user_notifications.admin_login.subject_template')).to eq(original_subject)
          expect(I18n.t('user_notifications.admin_login.text_body_template')).to eq(original_body)
        end

        it "doesn't create entries in the Staff Log" do
          put '/admin/customize/email_templates/user_notifications.admin_login', params: {
            email_template: { subject: email_subject, body: email_body }
          }, headers: headers

          log = UserHistory.find_by_subject('user_notifications.admin_login.subject_template')
          expect(log).to be_nil

          log = UserHistory.find_by_subject('user_notifications.admin_login.text_body_template')
          expect(log).to be_nil
        end
      end

      context "when subject is invalid" do
        let(:email_subject) { '%{email_wrongfix} Foo' }
        let(:email_body) { 'Body with missing interpolation keys' }

        let(:expected_errors) do
          [
            "<b>Subject</b>: #{I18n.t(
              'activerecord.errors.models.translation_overrides.attributes.value.invalid_interpolation_keys',
              keys: 'email_wrongfix'
            )}"
          ]
        end

        include_examples "invalid email template"
      end

      context "when body is invalid" do
        let(:email_subject) { 'Subject with missing interpolation key' }
        let(:email_body) { 'Body with %{invalid} interpolation key' }

        let(:expected_errors) do
          [
            "<b>Body</b>: #{I18n.t(
              'activerecord.errors.models.translation_overrides.attributes.value.invalid_interpolation_keys',
              keys: 'invalid'
            )}"
          ]
        end

        include_examples "invalid email template"
      end

      context "when subject and body are invalid invalid" do
        let(:email_subject) { 'Subject with %{invalid} interpolation key' }
        let(:email_body) { 'Body with some invalid interpolation keys: %{invalid}' }

        let(:expected_errors) do
          [
            "<b>Subject</b>: #{I18n.t(
              'activerecord.errors.models.translation_overrides.attributes.value.invalid_interpolation_keys',
              keys: 'invalid'
            )}",
            "<b>Body</b>: #{I18n.t(
              'activerecord.errors.models.translation_overrides.attributes.value.invalid_interpolation_keys',
              keys: 'invalid'
            )}",
          ]
        end

        include_examples "invalid email template"
      end

      context "when subject and body contain all required interpolation keys" do
        let(:email_subject) { '%{email_prefix} Foo' }
        let(:email_body) { 'The body contains [%{site_name}](%{base_url}) and %{email_token}.' }

        it "returns the successfully updated email template" do
          put '/admin/customize/email_templates/user_notifications.admin_login', params: {
            email_template: { subject: email_subject, body: email_body }
          }, headers: headers

          expect(response.status).to eq(200)

          json = ::JSON.parse(response.body)
          expect(json).to be_present

          template = json['email_template']
          expect(template).to be_present

          expect(template['id']).to eq('user_notifications.admin_login')
          expect(template['title']).to eq('Admin Login')
          expect(template['subject']).to eq(email_subject)
          expect(template['body']).to eq(email_body)
          expect(template['can_revert']).to eq(true)
        end

        it "creates translation overrides" do
          put '/admin/customize/email_templates/user_notifications.admin_login', params: {
            email_template: { subject: email_subject, body: email_body }
          }, headers: headers

          expect(I18n.t('user_notifications.admin_login.subject_template')).to eq(email_subject)
          expect(I18n.t('user_notifications.admin_login.text_body_template')).to eq(email_body)
        end

        it "creates entries in the Staff Log" do
          put '/admin/customize/email_templates/user_notifications.admin_login', params: {
            email_template: { subject: email_subject, body: email_body }
          }, headers: headers

          log = UserHistory.find_by_subject('user_notifications.admin_login.subject_template')

          expect(log).to be_present
          expect(log.action).to eq(UserHistory.actions[:change_site_text])
          expect(log.previous_value).to eq(original_subject)
          expect(log.new_value).to eq(email_subject)

          log = UserHistory.find_by_subject('user_notifications.admin_login.text_body_template')

          expect(log).to be_present
          expect(log.action).to eq(UserHistory.actions[:change_site_text])
          expect(log.previous_value).to eq(original_body)
          expect(log.new_value).to eq(email_body)
        end
      end

    end

  end

  context "#revert" do
    it "raises an error if you aren't logged in" do
      delete '/admin/customize/email_templates/some_id', headers: headers
      expect(response.status).to eq(404)
    end

    it "raises an error if you aren't an admin" do
      sign_in(user)
      delete '/admin/customize/email_templates/some_id', headers: headers
      expect(response.status).to eq(404)
    end

    context "when logged in as admin" do
      before do
        sign_in(admin)
      end

      it "returns 'not found' when an unknown email template id is used" do
        delete '/admin/customize/email_templates/non_existent_template', headers: headers
        expect(response).not_to be_successful

        json = ::JSON.parse(response.body)
        expect(json['error_type']).to eq('not_found')
      end

      context "when email template has translation overrides" do
        let(:email_subject) { '%{email_prefix} Foo' }
        let(:email_body) { 'The body contains [%{site_name}](%{base_url}) and %{email_token}.' }

        before do
          put '/admin/customize/email_templates/user_notifications.admin_login', params: {
            email_template: { subject: email_subject, body: email_body }
          }, headers: headers
        end

        it "restores the original subject and body" do
          expect(I18n.t('user_notifications.admin_login.subject_template')).to eq(email_subject)
          expect(I18n.t('user_notifications.admin_login.text_body_template')).to eq(email_body)

          delete '/admin/customize/email_templates/user_notifications.admin_login', headers: headers

          expect(I18n.t('user_notifications.admin_login.subject_template')).to eq(original_subject)
          expect(I18n.t('user_notifications.admin_login.text_body_template')).to eq(original_body)
        end

        it "returns the restored email template" do
          delete '/admin/customize/email_templates/user_notifications.admin_login', headers: headers
          expect(response.status).to eq(200)

          json = ::JSON.parse(response.body)
          expect(json).to be_present

          template = json['email_template']
          expect(template).to be_present

          expect(template['id']).to eq('user_notifications.admin_login')
          expect(template['title']).to eq('Admin Login')
          expect(template['subject']).to eq(original_subject)
          expect(template['body']).to eq(original_body)
          expect(template['can_revert']).to eq(false)
        end

        it "creates entries in the Staff Log" do
          UserHistory.delete_all
          delete '/admin/customize/email_templates/user_notifications.admin_login', headers: headers

          log = UserHistory.find_by_subject('user_notifications.admin_login.subject_template')

          expect(log).to be_present
          expect(log.action).to eq(UserHistory.actions[:change_site_text])
          expect(log.previous_value).to eq(email_subject)
          expect(log.new_value).to eq(original_subject)

          log = UserHistory.find_by_subject('user_notifications.admin_login.text_body_template')

          expect(log).to be_present
          expect(log.action).to eq(UserHistory.actions[:change_site_text])
          expect(log.previous_value).to eq(email_body)
          expect(log.new_value).to eq(original_body)
        end
      end
    end

  end

  it "uses only existing email templates" do
    Admin::EmailTemplatesController.email_keys.each do |key|
      expect(I18n.t(key)).to_not include('translation missing')
    end
  end
end
