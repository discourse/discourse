# frozen_string_literal: true

module PrettyText
  # The server-side markdown bundle, defined in a file of its own so that code
  # which runs the markdown pipeline outside a booted application can require
  # it directly — `PrettyText` itself is not loadable there.
  module CoreBundle
    # The only modules from the `discourse` package which may be bundled into the
    # server-side renderer. Additions must not transitively depend on
    # browser-only APIs.
    DISCOURSE_MODULES = %w[
      deprecation-workflow
      lib/avatar-utils
      lib/case-converter
      lib/escape
      lib/get-url
      lib/object
      loader
      static/markdown-it/features
    ]

    BUNDLE =
      PrecompiledBundle.new(
        dir: "tmp/pretty-text-processor",
        filename_prefix: "pretty-text",
        dependency_globs:
          %w[
            node_modules/.pnpm/lock.yaml
            frontend/pretty-text-processor/**/*.{js,mjs,cjs,json}
            frontend/pretty-text/addon/**/*.js
            frontend/discourse-markdown-it/src/**/*.js
          ] + DISCOURSE_MODULES.map { "frontend/discourse/app/#{it}.js" },
      ) do
        Discourse::Utils.execute_command(
          "pnpm",
          "-C=frontend/pretty-text-processor",
          "node",
          "build.mjs",
          "--discourse-modules=#{DISCOURSE_MODULES.join(",")}",
          chdir: Rails.root.to_s,
        )
      end
  end
end
