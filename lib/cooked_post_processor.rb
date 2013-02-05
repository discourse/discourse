# Post processing that we can do after a post has already been cooked. For
# example, inserting the onebox content, or image sizes.

require_dependency 'oneboxer'

class CookedPostProcessor

  def initialize(post, opts={})
    @dirty = false
    @opts = opts
    @post = post
    @doc = Hpricot(post.cooked)
  end

  def dirty?
    @dirty
  end

  # Bake onebox content into the post
  def post_process_oneboxes    
    args = {post_id: @post.id}
    args[:invalidate_oneboxes] = true if @opts[:invalidate_oneboxes]

    Oneboxer.each_onebox_link(@doc) do |url, element|
      onebox = Oneboxer.onebox(url, args)
      if onebox
        element.swap onebox 
        @dirty = true
      end
    end    
  end

  # First let's consider the images       
  def post_process_images    
    images = @doc.search("img")
    if images.present?

      # Extract the first image from the first post and use it as the 'topic image'
      if @post.post_number == 1
        img = images.first
        @post.topic.update_column :image_url, img['src'] if img['src'].present?
      end

      images.each do |img|
        if img['src'].present?

          # If we provided some image sizes, look those up first
          if @opts[:image_sizes].present?
            if dim = @opts[:image_sizes][img['src']]
              w, h = ImageSizer.resize(dim['width'], dim['height'])
              img.set_attribute 'width', w.to_s
              img.set_attribute 'height', h.to_s
              @dirty = true
            end
          end

          # If the image has no width or height, figure them out.
          if img['width'].blank? or img['height'].blank?               
            dim = CookedPostProcessor.image_dimensions(img['src'])
            if dim.present?
              img.set_attribute 'width', dim[0].to_s
              img.set_attribute 'height', dim[1].to_s
              @dirty = true
            end
          end

        end
      end
    end      
  end


  def post_process
    return unless @doc.present?
    post_process_images
    post_process_oneboxes
  end

  def html
    @doc.try(:to_html)
  end

  # Retrieve the image dimensions for a url
  def self.image_dimensions(url)
    return nil unless SiteSetting.crawl_images?
    uri = URI.parse(url)
    return nil unless %w(http https).include?(uri.scheme)
    w, h = FastImage.size(url)

    ImageSizer.resize(w, h)
  end

end
