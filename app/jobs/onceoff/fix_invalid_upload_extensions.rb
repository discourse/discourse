# frozen_string_literal: true

module Jobs
  class FixInvalidUploadExtensions < ::Jobs::Onceoff
    def execute_onceoff(args)
      UploadFixer.fix_all_extensions
    end
  end
end
