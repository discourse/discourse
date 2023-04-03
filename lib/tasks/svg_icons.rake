# frozen_string_literal: true

def vendor_svgs
  "#{Rails.root}/vendor/assets/svg-icons"
end

def library_src
  "#{Rails.root}/node_modules"
end

task "svgicons:update" do
  pnpm = system("pnpm install")
  abort('Unable to run "pnpm install"') unless pnpm

  dependencies = [{ source: "@fortawesome/fontawesome-free/sprites", destination: "fontawesome" }]

  start = Time.now

  dependencies.each do |f|
    src = "#{library_src}/#{f[:source]}/."
    filename = f[:destination] || f[:source].split("/").last
    dest = "#{vendor_svgs}/#{filename}"

    FileUtils.cp_r(src, dest)
  end

  STDERR.puts "Completed copying dependencies: #{(Time.now - start).round(2)} secs"
end
