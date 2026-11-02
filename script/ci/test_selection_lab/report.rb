# frozen_string_literal: true
require "json"
require "cgi"

raise ArgumentError, "Expected EVIDENCE OUTPUT" unless ARGV.length == 2
evidence, output = ARGV
escape = ->(value) { CGI.escapeHTML(value.to_s) }
read = ->(path) { File.file?(path) ? JSON.parse(File.read(path)) : nil }
campaign = read.call(File.join(evidence, "campaign.json"))
provenance =
  (
    if campaign
      "<details><summary>Campaign provenance</summary><pre>#{escape.call(JSON.pretty_generate(campaign))}</pre></details>"
    else
      ""
    end
  )
sections =
  Dir[File.join(evidence, "scenarios", "*")]
    .sort
    .map do |directory|
      expected = read.call("#{directory}/expected.json")
      next unless expected
      plan = read.call("#{directory}/plan.json")
      selected = read.call("#{directory}/selected.json")
      reference = read.call("#{directory}/full.json")
      result = read.call("#{directory}/result.json")
      files = plan&.fetch("files")
      missing = files ? expected.fetch("files") - files : []
      extra = files ? files - expected.fetch("files") : []
      missed_failures =
        selected && reference ? reference.fetch("failures") - selected.fetch("failures") : []
      complete =
        selected && reference &&
          [selected, reference].all? do |report|
            report["non_example_failure"] == false && report["unreported_failure"] == false
          end
      correct =
        result && result.fetch("correct") && plan && complete && missing.empty? && extra.empty? &&
          missed_failures.empty? && selected.fetch("exact") && reference.fetch("exact")
      rows =
        {
          "Expected files" => expected.fetch("files"),
          "Selected files" => files,
          "Assigned jobs" =>
            plan
              &.fetch("jobs")
              &.filter_map { |job, assigned| "#{job}: #{assigned.join(", ")}" if assigned.any? },
          "Files actually loaded" => selected&.fetch("loaded"),
          "Files with executed examples" => selected&.fetch("executed_files"),
          "Reference files loaded" => reference&.fetch("loaded"),
          "Reference files skipped by selection" =>
            selected && reference ? reference.fetch("loaded") - selected.fetch("loaded") : nil,
          "Executed example counts" =>
            (
              if selected && reference
                [
                  "Selected run: #{selected.fetch("examples")}",
                  "Reference run: #{reference.fetch("examples")}",
                ]
              else
                nil
              end
            ),
          "Missing files" => missing,
          "Unnecessary files" => extra,
          "Failures in the full reference" => reference&.fetch("failures"),
          "Failures in the selected run" => selected&.fetch("failures"),
          "Failures missed by selection" => missed_failures,
        }.map do |label, value|
            content = value.nil? ? "Not executed" : value.empty? ? "None" : value.join("\n")
            "<tr><th>#{escape.call(label)}</th><td><pre>#{escape.call(content)}</pre></td></tr>"
          end
          .join
      changes =
        (
          if File.file?("#{directory}/changes.diff")
            File.read("#{directory}/changes.diff")
          else
            "Unavailable"
          end
        )
      reasons = plan ? JSON.pretty_generate(plan.fetch("reasons")) : "Unavailable"
      fixture = read.call("#{directory}/fixture.json")
      inputs =
        (
          if fixture
            "<details><summary>Baseline application and spec code</summary>#{fixture.map { |path, source| "<h3>#{escape.call(path)}</h3><pre>#{escape.call(source)}</pre>" }.join}</details>"
          else
            ""
          end
        )
      "<section><h2>#{escape.call(File.basename(directory))}: #{correct ? "Passed" : "Incomplete or incorrect"}</h2><p>#{escape.call(expected.fetch("why"))}</p><p>Revision: <code>#{escape.call(plan&.fetch("revision"))}</code></p><table>#{rows}</table><details><summary>Changeset</summary><pre>#{escape.call(changes)}</pre></details>#{inputs}<details><summary>Selection reasons</summary><pre>#{escape.call(reasons)}</pre></details></section>"
    end
    .compact
html = <<~HTML
  <!doctype html>
  <html lang="en"><meta charset="utf-8"><title>Test file selection evidence</title>
  <style>body{font:16px system-ui;max-width:1100px;margin:32px auto;padding:0 20px;color:#20242a}section{margin:36px 0;border-top:1px solid #aaa}table{width:100%;border-collapse:collapse}th,td{text-align:left;vertical-align:top;padding:10px;border:1px solid #ddd}th{width:28%}pre{white-space:pre-wrap;overflow-wrap:anywhere;margin:0;font-size:13px}details{margin:16px 0}summary{cursor:pointer}</style>
  <h1>Test file selection evidence</h1>
  <p>Each changeset has an independently specified expected set, the planner result and recorded execution. The reference executes every file in this campaign's declared inventory. These observations cover these changesets and that inventory, not every possible future change.</p>
  #{provenance}
  #{sections.join("\n")}
  </html>
HTML
File.write(output, html)
