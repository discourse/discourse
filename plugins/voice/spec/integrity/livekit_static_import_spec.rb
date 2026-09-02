# frozen_string_literal: true

# "Zero LiveKit bytes on the P2P path" as a regression test: the vendored
# SDK bundle must stay out of the app graph, reachable only through the
# dynamic `import()` in `livekit-session.js` that runs when a room actually
# resolves to the livekit transport. A static import — of the vendored
# bundle path or of the `livekit-client` npm package (a build-time
# devDependency only) — would ship and parse the SDK for every visitor of
# every mesh-only install.
RSpec.describe "LiveKit SDK static import guard" do
  # `from "<specifier>"` only occurs in static import/export statements —
  # dynamic `import()` never uses `from` — and `import "<specifier>"` is a
  # static side-effect import.
  FORBIDDEN_SPECIFIER = %r{livekit-client|[^"']*javascripts/livekit/[^"']*}
  STATIC_IMPORT =
    Regexp.union(
      /\bfrom\s+["'](?:#{FORBIDDEN_SPECIFIER})["']/,
      /\bimport\s+["'](?:#{FORBIDDEN_SPECIFIER})["']/,
    )

  def offenders_in(content)
    content.match?(STATIC_IMPORT)
  end

  it "finds no static import of the SDK anywhere under the asset directories" do
    plugin_root = File.expand_path("../..", __dir__)
    files = Dir.glob("#{plugin_root}/{assets,admin/assets}/**/*.{js,gjs}")
    expect(files).not_to be_empty

    offenders = files.select { |path| offenders_in(File.read(path)) }
    expect(offenders.map { |path| path.delete_prefix("#{plugin_root}/") }).to eq([])
  end

  # Pin the pattern itself, so the guard cannot rot into matching nothing.
  it "catches every static import form" do
    [
      'import { Room } from "livekit-client";',
      "import * as livekit from 'livekit-client';",
      'import "livekit-client";',
      'export { Room } from "livekit-client";',
      'import lk from "../../../public/javascripts/livekit/livekit-client";',
      "import {\n  Room,\n  RoomEvent,\n} from \"livekit-client\";",
    ].each { |snippet| expect(offenders_in(snippet)).to eq(true), "expected match: #{snippet}" }
  end

  it "allows the dynamic import the session uses" do
    [
      'import(getURL("/plugins/voice/javascripts/livekit/livekit-client.js"))',
      'import LivekitRoomSession from "../../lib/voice/livekit-session";',
    ].each { |snippet| expect(offenders_in(snippet)).to eq(false), "expected no match: #{snippet}" }
  end
end
