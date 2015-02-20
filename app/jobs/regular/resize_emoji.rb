module Jobs

  class ResizeEmoji < Jobs::Base

    def execute(args)
      path = args[:path]
      return unless File.exists?(path)

      # make sure emoji aren't too big
      OptimizedImage.downsize(path, path, 60, 60, true)
    end
  end

end
