class IncomingDomain < ActiveRecord::Base
  def self.add!(uri)
    name = uri.host
    https = uri.scheme == "https"
    port = uri.port

    current = find_by(name: name, https: https, port: port)
    return current if current

    # concurrency ...

    begin
      current = create!(name: name, https: https, port: port)
    rescue ActiveRecord::RecordNotUnique
      # duplicate key is just ignored
    end

    current || find_by(name: name, https: https, port: port)
  end

  def to_url
    url = "http#{https ? "s" : ""}://#{name}"

    if https && port != 443 || !https && port != 80
      url << ":#{port}"
    end

    url
  end
end

# == Schema Information
#
# Table name: incoming_domains
#
#  id    :integer          not null, primary key
#  name  :string(100)      not null
#  https :boolean          default(FALSE), not null
#  port  :integer          not null
#
# Indexes
#
#  index_incoming_domains_on_name_and_https_and_port  (name,https,port) UNIQUE
#
