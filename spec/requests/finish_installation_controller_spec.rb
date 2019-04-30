# frozen_string_literal: true

require 'rails_helper'

describe FinishInstallationController do

  describe '#index' do
    context "has_login_hint is false" do
      before do
        SiteSetting.has_login_hint = false
      end

      it "doesn't allow access" do
        get "/finish-installation"
        expect(response).to be_forbidden
      end
    end

    context "has_login_hint is true" do
      before do
        SiteSetting.has_login_hint = true
      end

      it "allows access" do
        get "/finish-installation"
        expect(response.status).to eq(200)
      end
    end
  end

  describe '#register' do
    context "has_login_hint is false" do
      before do
        SiteSetting.has_login_hint = false
      end

      it "doesn't allow access" do
        get "/finish-installation/register"
        expect(response).to be_forbidden
      end
    end

    context "has_login_hint is true" do
      before do
        SiteSetting.has_login_hint = true
        GlobalSetting.stubs(:developer_emails).returns("robin@example.com")
      end

      it "allows access" do
        get "/finish-installation/register"
        expect(response.status).to eq(200)
      end

      it "raises an error when the email is not in the allowed list" do
        post "/finish-installation/register.json", params: {
          email: 'notrobin@example.com',
          username: 'eviltrout',
          password: 'disismypasswordokay'
        }
        expect(response.status).to eq(400)
      end

      it "doesn't redirect when fields are wrong" do
        post "/finish-installation/register", params: {
          email: 'robin@example.com',
          username: '',
          password: 'disismypasswordokay'
        }

        expect(response).not_to be_redirect
      end

      context "working params" do
        let(:params) do
          {
            email: 'robin@example.com',
            username: 'eviltrout',
            password: 'disismypasswordokay'
          }
        end

        it "registers the admin when the email is in the list" do
          expect do
            post "/finish-installation/register.json", params: params
          end.to change { Jobs::CriticalUserEmail.jobs.size }.by(1)

          expect(response).to be_redirect
          expect(User.where(username: 'eviltrout').exists?).to eq(true)
        end

        it "automatically resends the signup email when the user already exists" do
          expect do
            post "/finish-installation/register.json", params: params
          end.to change { Jobs::CriticalUserEmail.jobs.size }.by(1)

          expect(User.where(username: 'eviltrout').exists?).to eq(true)

          expect do
            post "/finish-installation/register.json", params: params
          end.to change { Jobs::CriticalUserEmail.jobs.size }.by(1)

          expect(response).to be_redirect
          expect(User.where(username: 'eviltrout').exists?).to eq(true)
        end
      end

      it "sets the admins trust level" do
        post "/finish-installation/register.json", params: {
          email: 'robin@example.com',
          username: 'eviltrout',
          password: 'disismypasswordokay'
        }

        expect(User.find_by(username: 'eviltrout').trust_level).to eq 1
      end
    end
  end

  describe '#confirm_email' do
    context "has_login_hint is false" do
      before do
        SiteSetting.has_login_hint = false
      end

      it "shows the page" do
        get "/finish-installation/confirm-email"
        expect(response.status).to eq(200)
      end
    end
  end

  describe '#resend_email' do
    before do
      SiteSetting.has_login_hint = true
      GlobalSetting.stubs(:developer_emails).returns("robin@example.com")

      post "/finish-installation/register", params: {
        email: 'robin@example.com',
        username: 'eviltrout',
        password: 'disismypasswordokay'
      }
    end

    it "resends the email" do
      expect do
        put "/finish-installation/resend-email"
      end.to change { Jobs::CriticalUserEmail.jobs.size }.by(1)

      expect(response.status).to eq(200)
    end
  end
end
