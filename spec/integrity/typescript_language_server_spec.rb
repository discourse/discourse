# frozen_string_literal: true

require "open3"

# Drives the TypeScript language server the way an editor does, from a bundled
# plugin file that imports core modules. Core must resolve to source through the
# project reference, so the checks hold even when nothing has been emitted.
RSpec.describe "TypeScript language server" do
  class LanguageServer
    def initialize(root)
      @root = root
      @next_id = 0
      @stdin, @stdout, @wait =
        Open3.popen2(
          "node",
          "node_modules/typescript-7/bin/tsc",
          "--lsp",
          "--stdio",
          chdir: root,
          err: File::NULL,
        )
    end

    def request(method, params)
      id = (@next_id += 1)
      write(id:, method:, params:)
      loop do
        message = read
        return message["result"] if message["id"] == id
        # Answer the server's own requests so it does not wait on us.
        write(id: message["id"], result: nil) if message["id"] && message["method"]
      end
    end

    def notify(method, params = nil)
      write(params.nil? ? { method: } : { method:, params: })
    end

    def close
      request("shutdown", nil)
      notify("exit")
      @stdin.close
      @wait.value
    ensure
      @stdout.close
    end

    private

    def write(message)
      body = { jsonrpc: "2.0", **message }.to_json
      @stdin.write("Content-Length: #{body.bytesize}\r\n\r\n#{body}")
      @stdin.flush
    end

    def read
      Timeout.timeout(60) do
        length = nil
        while (line = @stdout.readline.chomp) != ""
          length = Integer(line.delete_prefix("Content-Length: ")) if line.start_with?(
            "Content-Length:",
          )
        end
        JSON.parse(@stdout.read(length))
      end
    end
  end

  let(:root) { Rails.root.to_s }
  let(:probe_file) { "plugins/chat/assets/javascripts/discourse/language-server-probe.ts" }
  let(:probe_uri) { "file://#{root}/#{probe_file}" }

  # Module specifier, the binding to look up, and the core source file that
  # "go to definition" on that binding must land in.
  let(:imports) do
    [
      ["discourse/lib/later", "* as later", "later", "frontend/discourse/app/lib/later.ts"],
      ["discourse/lib/ajax", "{ ajax }", "ajax", "frontend/discourse/app/lib/ajax.js"],
      %w[discourse/ui-kit/d-button DButton DButton frontend/discourse/app/ui-kit/d-button.gts],
      %w[
        discourse/components/pinned-button
        PinnedButton
        PinnedButton
        frontend/discourse/app/components/pinned-button.gjs
      ],
    ]
  end

  let(:probe_source) do
    imports.map { |specifier, binding, _, _| "import #{binding} from \"#{specifier}\";\n" }.join +
      "export const probe = [#{imports.map { |_, _, name, _| name }.join(", ")}];\n"
  end

  def definition_uris(server, line, character)
    result =
      server.request(
        "textDocument/definition",
        textDocument: {
          uri: probe_uri,
        },
        position: {
          line:,
          character:,
        },
      )
    Array.wrap(result).map { |location| location["targetUri"] || location["uri"] }
  end

  it "resolves core imports from a plugin to core source" do
    server = LanguageServer.new(root)
    server.request(
      "initialize",
      processId: Process.pid,
      rootUri: "file://#{root}",
      capabilities: {
      },
      initializationOptions: {
        runExternalCode: true,
      },
    )
    server.notify("initialized", {})
    server.notify(
      "textDocument/didOpen",
      textDocument: {
        uri: probe_uri,
        languageId: "typescript",
        version: 1,
        text: probe_source,
      },
    )

    imports.each_with_index do |(_, _, name, source_file), line|
      character = probe_source.lines[line].index(name)
      expect(definition_uris(server, line, character)).to eq(["file://#{root}/#{source_file}"]),
      name
    end

    diagnostics = server.request("textDocument/diagnostic", textDocument: { uri: probe_uri })
    expect(diagnostics["items"]).to eq([])
  ensure
    server&.close
  end
end
