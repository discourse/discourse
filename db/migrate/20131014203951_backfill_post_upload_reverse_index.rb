class BackfillPostUploadReverseIndex < ActiveRecord::Migration

  def up
    # clean the reverse index
    execute "TRUNCATE TABLE post_uploads"

    # fill the reverse index up
    Post.select([:id, :cooked]).find_each do |post|
      doc = Nokogiri::HTML::fragment(post.cooked)
      # images
      doc.search("img").each { |img| add_to_reverse_index(img['src'], post.id) }
      # thumbnails and/or attachments
      doc.search("a").each { |a| add_to_reverse_index(a['href'], post.id) }
    end
  end

  def add_to_reverse_index(url, post_id)
    # make sure we have a url to insert
    return unless url.present?
    # local uploads are relative
    if index = url.index(local_base_url)
      url = url[index..-1]
    end
    # filter out non-uploads
    return unless url.starts_with?(local_base_url) || url.starts_with?(s3_base_url)
    # update the reverse index
    execute "INSERT INTO post_uploads (upload_id, post_id)
             SELECT u.id, #{post_id}
             FROM uploads u
             WHERE u.url = '#{url}'
             AND NOT EXISTS (SELECT 1 FROM post_uploads WHERE upload_id = u.id AND post_id = #{post_id})"
  end

  def local_base_url
    @local_base_url ||= "/uploads/#{RailsMultisite::ConnectionManagement.current_db}"
  end

  def s3_base_url
    @s3_base_url ||= "//#{SiteSetting.s3_upload_bucket.downcase}.s3.amazonaws.com"
  end

end
