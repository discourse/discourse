def vendor_svgs
  "#{Rails.root}/vendor/assets/svg-icons"
end

def library_src
  "#{Rails.root}/node_modules"
end

task 'svgs:update' do

  yarn = system("yarn install")
  abort('Unable to run "yarn install"') unless yarn

  dependencies = [
    {
      source: '@fortawesome/fontawesome-free/sprites',
      destination: 'fontawesome',
    }
  ]

  start = Time.now

  dependencies.each do |f|
    src = "#{library_src}/#{f[:source]}"

    unless f[:destination]
      filename = f[:source].split("/").last
    else
      filename = f[:destination]
    end

    dest = "#{vendor_svgs}/#{filename}"

    FileUtils.cp_r(src, dest)
  end

  STDERR.puts "Completed copying dependencies: #{(Time.now - start).round(2)} secs"
end

task 'svgs:subset' do
  require 'nokogiri'

  @icons = 'surprise|sun|thumbs-up|smile'
  @doc = Nokogiri::XML(File.open("#{Rails.root}/vendor/assets/svg-icons/fontawesome/regular.svg")) do |config|
    config.options = Nokogiri::XML::ParseOptions::NOBLANKS
  end

  @doc.css('symbol').each do |sym|
    unless @icons.include? sym.attr('id')
      sym.remove
    end
  end

  File.write("#{Rails.root}/vendor/assets/svg-icons/fontawesome/subset.svg", @doc.to_xml)

end
