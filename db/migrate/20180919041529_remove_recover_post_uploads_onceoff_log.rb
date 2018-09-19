class RemoveRecoverPostUploadsOnceoffLog < ActiveRecord::Migration[5.2]
  def up
    DB.exec("DELETE FROM onceoff_logs WHERE job_name = 'RecoverPostUploads'")
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
