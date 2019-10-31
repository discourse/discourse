# frozen_string_literal: true

class BackupFileSerializer < ApplicationSerializer
  root 'backup_file'

  attributes :filename,
             :size,
             :last_modified
end
