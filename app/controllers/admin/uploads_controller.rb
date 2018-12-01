class Admin::UploadsController < Admin::AdminController

  def index
    disk_space_stats = DiskSpace.stats
    data = {
      uploads: Upload.all.to_a,
      uploads_used: disk_space_stats[:uploads_used],
      uploads_free: disk_space_stats[:uploads_free],
    }
    render_serialized(OpenStruct.new(data), AdminUploadsSerializer)
  end

end
