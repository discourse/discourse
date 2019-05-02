# frozen_string_literal: true

class BackupFileSerializer < ApplicationSerializer
  attributes :filename,
             :size,
             :last_modified
end
