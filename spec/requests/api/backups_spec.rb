# frozen_string_literal: true
require 'swagger_helper'

describe 'backups' do

  let(:admin) { Fabricate(:admin) }
  let(:backup_filename) { "2021-02-10-065935.tar.gz" }
  let(:backup_filename2) { "2021-02-11-065935.tar.gz" }

  def create_backup_files(*filenames)
    @paths = filenames.map do |filename|
      path = backup_path(filename)
      File.open(path, "w") { |f| f.write("test backup") }
      path
    end
  end

  def backup_path(filename)
    File.join(BackupRestore::LocalBackupStore.base_directory, filename)
  end

  before do
    Jobs.run_immediately!
    sign_in(admin)
    SiteSetting.backup_location = BackupLocationSiteSetting::LOCAL
    create_backup_files(backup_filename)
  end

  after do
    Discourse.redis.flushdb

    @paths&.each { |path| File.delete(path) if File.exist?(path) }
    @paths = nil
  end

  path '/admin/backups.json' do
    get 'List backups' do
      tags 'Backups'
      operationId 'getBackups'
      consumes 'application/json'
      expected_request_schema = nil

      produces 'application/json'
      response '200', 'success response' do
        expected_response_schema = load_spec_schema('backups_list_response')
        schema expected_response_schema

        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end
    end

    post 'Create backup' do
      tags 'Backups'
      operationId 'createBackup'
      consumes 'application/json'
      expected_request_schema = load_spec_schema('backups_create_request')
      parameter name: :params, in: :body, schema: expected_request_schema

      produces 'application/json'
      response '200', 'success response' do
        expected_response_schema = load_spec_schema('success_ok_response')
        schema expected_response_schema

        #BackupRestore.expects(:backup!).with(admin.id, publish_to_message_bus: true, with_uploads: false, client_id: "foo")
        let(:params) { { 'with_uploads' => false } }

        #it_behaves_like "a JSON endpoint", 200 do
        #  let(:expected_response_schema) { expected_response_schema }
        #  let(:expected_request_schema) { expected_request_schema }
        #end

        # Skipping this test for now because mocking of BackupRestore isn't working for some reason.
        # Without mocking it spawns a background process which we don't want to happen in our tests.
        # This still allows the API docs to be generated for this endpoint.
        xit
      end
    end
  end

  path '/admin/backups/{filename}' do
    put 'Send download backup email' do
      tags 'Backups'
      operationId 'sendDownloadBackupEmail'
      consumes 'application/json'
      expected_request_schema = nil
      parameter name: :filename, in: :path, type: :string, required: true

      produces 'application/json'
      response '200', 'success response' do
        expected_response_schema = nil

        let(:filename) { backup_filename }

        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end
    end

    get 'Download backup' do
      tags 'Backups'
      operationId 'downloadBackup'
      consumes 'application/json'
      expected_request_schema = nil
      parameter name: :filename, in: :path, type: :string, required: true
      parameter name: :token, in: :query, type: :string, required: true

      produces 'application/json'
      response '200', 'success response' do
        expected_response_schema = nil

        let(:filename) { backup_filename }
        let(:token) { EmailBackupToken.set(admin.id) }

        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end
    end
  end
end
