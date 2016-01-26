class DiskSpace

  extend ActionView::Helpers::NumberHelper

  def self.uploads_used_bytes
    # used(uploads_path)
    # temporary (on our internal setup its just too slow to iterate)
    Upload.sum(:filesize).to_i
  end

  def self.uploads_free_bytes
    free(uploads_path)
  end

  def self.backups_used_bytes
    used(backups_path)
  end

  def self.backups_free_bytes
    free(backups_path)
  end

  def self.backups_path
    Backup.base_directory
  end

  def self.uploads_path
    "#{Rails.root}/public/uploads/#{RailsMultisite::ConnectionManagement.current_db}"
  end

  def self.stats
    {
      uploads_used: number_to_human_size(uploads_used_bytes),
      uploads_free: number_to_human_size(uploads_free_bytes),
      backups_used: number_to_human_size(backups_used_bytes),
      backups_free: number_to_human_size(backups_free_bytes)
    }
  end

  def self.cached_stats
    stats = $redis.get('disk_space_stats')
    updated_at = $redis.get('disk_space_stats_updated')

    unless updated_at && (Time.now.to_i - updated_at.to_i) < 30.minutes
      Scheduler::Defer.later "updated stats" do
        $redis.set('disk_space_stats_updated', Time.now.to_i)
        $redis.set('disk_space_stats', self.stats.to_json)
      end
    end

    if stats
      JSON.parse(stats)
    end

  end

  protected

  def self.free(path)
    `df -Pk #{path} | awk 'NR==2 {print $4;}'`.to_i * 1024
  end

  def self.used(path)
    `du -s #{path}`.to_i * 1024
  end

end
