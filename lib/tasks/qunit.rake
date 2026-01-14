# frozen_string_literal: true

desc "Runs the qunit test suite"
task "qunit:test", %i[qunit_path filter] do |_, args|
  cmd = [Rails.root.join("bin/qunit").to_s, "--standalone"]
  cmd += ["--qunit-path", args[:qunit_path]] if args[:qunit_path]

  filter_arg = args[:filter] || ENV["FILTER"]
  cmd += ["--filter", filter_arg] if filter_arg

  system(ENV, *cmd, chdir: Rails.root)
  exit $?.exitstatus
end
