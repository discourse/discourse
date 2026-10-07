# frozen_string_literal: true

# `script/copy_vendored_assets.mjs` copies these dependencies out of `node_modules` during `pnpm install`,
# so that a production install does not need to keep `node_modules` around.
module VendoredAssets
  DIRECTORY = "vendor/runtime_node_modules"

  def self.path(relative_path)
    Rails.root.join(DIRECTORY, relative_path)
  end
end
