# frozen_string_literal: true

def vendor_svgs
  "#{Rails.root}/vendor/assets/svg-icons"
end

def library_src
  "#{Rails.root}/node_modules"
end

task "svgicons:update" do
  yarn = system("yarn install")
  abort('Unable to run "yarn install"') unless yarn

  dependencies = [{ source: "@fortawesome/fontawesome-free/sprites", destination: "fontawesome" }]

  start = Time.now

  dependencies.each do |f|
    src = "#{library_src}/#{f[:source]}/."

    if f[:destination]
      filename = f[:destination]
    else
      filename = f[:source].split("/").last
    end

    dest = "#{vendor_svgs}/#{filename}"

    FileUtils.cp_r(src, dest)
  end

  STDERR.puts "Completed copying dependencies: #{(Time.now - start).round(2)} secs"
end
