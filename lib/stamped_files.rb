# frozen_string_literal: true

module StampedFiles
  def self.update_filename(filename)
    if filename[-3..-1] == '.js'
      "#{filename[0..-4]}-#{StampedFiles.git_hash}.js"
    else
      "#{filename}-#{StampedFiles.git_hash}"
    end
  end

  def self.git_hash
    @git_hash ||= begin
      git_cmd = 'git rev-parse HEAD:public/javascripts'
      Discourse.try_git(git_cmd, 'unknown')

      # TODO - remove this, it's just for debugging
      # SecureRandom.hex(20)
    end
  end

  def self.revision_filename
    filename = Rails.env.test? ? "REVISION.test" : "REVISION"
    File.join(Rails.root, 'public', 'javascripts', filename)
  end

  def self.cleanup(revisions_to_keep = 0, specific_git_hash = nil)
    if specific_git_hash.present? && !!specific_git_hash[/\H/]
      raise 'specific_git_hash invalid'
    end

    file_pattern = specific_git_hash ? "*#{specific_git_hash}*" : '*'
    dir_contents = Dir.glob(File.join(Rails.root, 'public', 'javascripts', file_pattern))

    # Keep anything that doesn't appear to have been stamped
    file_regex, dir_regex = StampedFiles.regexes
    dir_contents.delete_if do |filename|
      if File.file?(filename)
        filename !~ file_regex
      elsif File.directory?(filename)
        filename !~ dir_regex
      end
    end

    revisions = {}
    dir_contents.each do |filename|
      name, _, suffix = filename.rpartition('-')
      revisions[name] = [] unless revisions[name]
      revisions[name] << filename
    end

    revisions.each_key do |filename|
      files_to_delete = revisions[filename].sort_by { |f| File.mtime(f) }

      # Take a subset of known stamped files
      files_to_delete = files_to_delete[0...-revisions_to_keep] if revisions_to_keep > 0

      files_to_delete.each { |delete_file| FileUtils.remove_dir(delete_file) }
    end

    if revisions_to_keep == 0
      FileUtils.rm_f(StampedFiles.revision_filename)
    end
  end

  def self.regexes
    [/(-{1}[a-z0-9]{40}*\.{1}){1}/, /(-{1}[a-z0-9]{40}$){1}/]
  end
end
