# frozen_string_literal: true

if Rails.env.local?
  begin
    Discourse::Utils.execute_command("vips", "--version", timeout: 5)
  rescue Discourse::Utils::CommandError, Errno::ENOENT
    raise Discourse::Utils::CommandError, <<~TEXT.strip
            vips --version

            Discourse requires the `vips` command for image processing, but it could not be run.

            Install libvips, then restart Discourse:
            https://www.libvips.org/install.html
          TEXT
  end
end
