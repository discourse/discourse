module OmnibusTrucker
  class << self
    URL_MAP = {
      :p => :platform, :pv => :platform_version, :m => :machine,
      :v => :version, :prerelease => :prerelease,
      :nightlies => :nightlies
    }

    def build_url(*opts)
      args = node = nil
      opts.each do |o|
        if(o.kind_of?(Hash))
          args = o
        elsif(o.kind_of?(Chef::Node))
          node = o
        else
          raise ArgumentError.new "Provided argument is not allowed: #{o.class}"
        end
      end
      args ||= {}
      if(node)
        args = collect_attributes(node).merge(args)
      end
      url = args[:url] || "http://www.opscode.com/chef/download#{'-server' if args[:server]}"
      u_args = URL_MAP.map do |u_k, a_k|
        "#{u_k}=#{args[a_k]}" unless args[a_k].nil?
      end.compact
      "#{url}?#{u_args.join('&')}"
    end

    def collect_attributes(node, args={})
      set = Hash[*(
          [:platform_family, :platform, :platform_version].map do |k|
            [k, args[k] || node[k]]
          end.flatten.compact
      )]
      unless(@attrs)
        if(set[:platform_family] == 'rhel')
          @attrs = {:platform => 'el', :platform_version => set[:platform_version].to_i}
        else
          @attrs = {:platform => set[:platform], :platform_version => set[:platform_version]}
        end
        @attrs[:machine] = args[:machine] || node[:kernel][:machine]
      end
      @attrs
    end

    def url(url_or_node, node = nil)
      if(url_or_node.is_a?(Chef::Node))
        url = build_url(url_or_node)
        node = url_or_node
      else
        url = url_or_node
        raise "Node instance is required for Omnitruck.url!" unless node
      end
      request = Chef::REST::RESTRequest.new(:head, URI.parse(url), nil)
      result = request.call
      if(result.kind_of?(Net::HTTPRedirection))
        result['location']
      end
    end

  end
end
