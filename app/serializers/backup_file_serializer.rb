class BackupFileSerializer < ApplicationSerializer
  attributes :filename,
             :size,
             :last_modified
end
