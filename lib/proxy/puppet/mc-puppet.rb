module Proxy::Puppet
  module McPuppet
    require 'mcollective'
    include MCollective::RPC
    class << self
      def run hosts
        puppetd = rpcclient("puppetd")
        result = []
        hosts.each do |host|
          result << puppetd.custom_request("runonce", {:forcerun => true}, host, {"identity" => host})

        end
        result
      end
    end
  end
end
