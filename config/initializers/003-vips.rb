# frozen_string_literal: true

if Rails.env.local?
  begin
    Discourse::Utils.execute_command("vips", "--version")
  rescue Discourse::Utils::CommandError, Errno::ENOENT
    raise Discourse::Utils::CommandError, <<~TEXT.strip
            vips --version

            Discourse requires the `vips` command for image processing, but it could not be run.

            Install libvips, then restart Discourse:
            https://github.com/libvips/libvips/wiki#building-and-installing
          TEXT
  end
end
