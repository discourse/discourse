require_dependency "upload_fixer"

module Jobs
  class FixInvalidUploadExtensions < Jobs::Onceoff
    def execute_onceoff(args)
      UploadFixer.fix_all_extensions
    end
  end
end
