module Jobs

  class ResizeEmoji < Jobs::Base

    def execute(args)
      path = args[:path]
      return unless File.exists?(path)

      opts = {
        allow_animation: true,
        force_aspect_ratio: SiteSetting.enforce_square_emoji
      }
      # make sure emoji aren't too big
      OptimizedImage.downsize(path, path, 60, 60, opts)
    end
  end

end
