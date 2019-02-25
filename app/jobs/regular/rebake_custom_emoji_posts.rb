module Jobs
  class RebakeCustomEmojiPosts < Jobs::Base
    def execute(args)
      Post.where("raw LIKE ?", "%:#{args[:name]}:%").find_each(&:rebake!)
    end
  end
end
